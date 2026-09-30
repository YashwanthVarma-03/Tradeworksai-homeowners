"""Run arrival and booking migrations in a disposable local PostgreSQL cluster.

Uses synthetic schema/data only. Does not use Supabase credentials or settings.
The cluster is stopped in finally; files remain in ignored .repo_ref for inspection.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import json
from pathlib import Path
import socket
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BIN = Path(r'C:\Program Files\PostgreSQL\18\bin')
WORK = ROOT / '.repo_ref' / ('sql-checks-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
WORK.mkdir(parents=True)
DATA = WORK / 'data'
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    PORT = sock.getsockname()[1]
FLAGS = getattr(subprocess, 'CREATE_NO_WINDOW', 0)


def run(args, check=True):
    if Path(args[0]).name == 'pg_ctl.exe':
        # A Windows server child can inherit capture pipes and hold them open.
        with (WORK/'control.log').open('a') as output:
            result = subprocess.run([str(arg) for arg in args], stdout=output, stderr=output,
                                    creationflags=FLAGS, timeout=45)
        if check and result.returncode:
            raise RuntimeError('pg_ctl failed; see control.log')
        return result
    result = subprocess.run([str(arg) for arg in args], capture_output=True,
                            text=True, creationflags=FLAGS, timeout=45)
    if check and result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result


def sql(text, check=True):
    return run([BIN/'psql.exe', '-X', '-w', '-h', '127.0.0.1', '-p', PORT, '-U', 'batch_tests',
                '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At', '-c', text], check)


schema = '''
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE TABLE home_profiles(id bigint PRIMARY KEY);
CREATE TABLE contractor_profiles(id bigint PRIMARY KEY,user_id bigint);
CREATE TABLE availability_settings(contractor_id bigint,concurrent_capacity int,buffer_minutes int);
CREATE TABLE slot_holds(id bigint PRIMARY KEY,contractor_id bigint,expires_at timestamptz,starts_at timestamptz,ends_at timestamptz);
CREATE TABLE work_orders(
 id bigserial PRIMARY KEY,wo_number text,status text,requester_user_id bigint,assigned_contractor_user_id bigint,
 scheduled_start timestamptz,scheduled_end timestamptz,scheduled_date timestamptz,updated_at timestamptz,
 requester_name text,requester_phone text,requester_email text,service_category text,service_description text,
 address_street text,address_city text,address_state text,address_zip text,access_instructions text,
 priority text,work_order_type text,estimated_duration_minutes int,property_timezone text,
 auto_accepted bool,sla_arrival_target timestamptz,dispatched_at timestamptz,accepted_at timestamptz);
INSERT INTO contractor_profiles VALUES (10,20);
INSERT INTO availability_settings VALUES (10,1,0);
INSERT INTO work_orders(id,requester_user_id,status,scheduled_end)
 VALUES (100,7,'accepted',now()-interval '40 days'), (101,7,'accepted',now()-interval '3 hours'),
 (102,7,'accepted',now()-interval '3 hours'),(103,7,'accepted',now()+interval '1 hour');
'''

started = False
try:
    run([BIN/'initdb.exe', '-D', DATA, '-U', 'batch_tests', '-A', 'trust', '--no-locale'])
    run([BIN/'pg_ctl.exe', '-D', DATA, '-l', WORK/'server.log', '-o', f'-h 127.0.0.1 -p {PORT}', '-w', 'start'])
    started = True
    sql(schema)
    for file in ['20260926_arrival_cases.sql', '20260928_platform_home_context.sql']:
        sql((ROOT/'backend/migrations'/file).read_text(encoding='utf-8'))
    source = ROOT/'.repo_ref/platform-backend-reference/backend/sql/rpcs/book_slot.sql'
    sql(source.read_text(encoding='utf-8').rstrip() + ';')
    assert sql('SELECT count(*) FROM pending_arrival_checks').stdout.strip() == '3'
    assert sql("SELECT resolve_arrival_check(100,99,'pro_no_show','')", check=False).returncode != 0
    assert sql("SELECT resolve_arrival_check(103,7,'pro_no_show','')", check=False).returncode != 0
    sql("SELECT resolve_arrival_check(100,7,'confirm_arrival','')")
    sql("SELECT resolve_arrival_check(101,7,'arrival_rescheduled','')")
    sql("SELECT resolve_arrival_check(102,7,'pro_no_show','No arrival')")
    sql("SELECT resolve_arrival_check(102,7,'pro_no_show','Retry')")
    assert sql('SELECT count(*) FROM arrival_cases').stdout.strip() == '1'
    assert sql("SELECT status FROM work_orders WHERE id=100").stdout.strip() == 'accepted'
    assert sql('SELECT count(*) FROM pending_arrival_checks').stdout.strip() == '0'
    assert sql("SELECT has_function_privilege('authenticated','resolve_arrival_check(bigint,bigint,text,text)','EXECUTE')").stdout.strip() == 'f'
    print('PASS: private arrival queue, silence, ownership, grace, answers and idempotency')

    booking = "SELECT book_slot(10,NULL,now()+interval '5 days',now()+interval '5 days 2 hours','standard','UTC','{\"requester_user_id\":7}')"
    # Use a fixed timestamp in both transactions so they truly contend for one window.
    start = sql("SELECT (now()+interval '5 days')::text").stdout.strip()
    booking = f"SELECT book_slot(10,NULL,'{start}'::timestamptz,'{start}'::timestamptz+interval '2 hours','standard','UTC','{{\"requester_user_id\":7}}')"
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: json.loads(sql(booking).stdout), range(2)))
    assert sum(result.get('ok') is True for result in results) == 1, results
    assert any(result.get('reason') == 'slot_taken' for result in results), results
    good = next(result for result in results if result.get('ok'))
    assert good['slaArrivalTarget'] is None
    invalid = sql("SELECT book_slot(10,NULL,now()+interval '8 days',now()+interval '8 days 1 hour','standard','UTC','{}')")
    assert json.loads(invalid.stdout)['reason'] == 'invalid_arrival_window'
    late = sql("SELECT book_slot(10,NULL,now()+interval '2 days',now()+interval '2 days 2 hours','urgent','UTC','{}')")
    assert json.loads(late.stdout)['reason'] == 'response_deadline_unavailable'
    print('PASS: concurrent booking conflict, Standard without 48h deadline, window and urgent limits')
finally:
    if started:
        run([BIN/'pg_ctl.exe', '-D', DATA, '-m', 'fast', '-w', 'stop'])
