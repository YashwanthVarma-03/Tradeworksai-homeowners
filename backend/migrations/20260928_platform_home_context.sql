-- Current platform schema; this does not install the superseded home_profiles_v2 model.
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS home_profile_id bigint
  REFERENCES public.home_profiles(id);
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS homeowner_no_show_reply text;
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS homeowner_no_show_replied_at timestamptz;

-- A private operational queue. No answer is never an automatic no-show.
CREATE OR REPLACE VIEW public.pending_arrival_checks AS
SELECT id AS work_order_id, requester_user_id, assigned_contractor_user_id,
       scheduled_end, scheduled_end + interval '2 hours' AS check_opened_at
FROM public.work_orders
WHERE status IN ('accepted','en_route','arrived','in_progress','pending_completion')
  AND scheduled_end + interval '2 hours' <= now()
  AND arrival_check_resolved_end IS DISTINCT FROM scheduled_end;
REVOKE ALL ON public.pending_arrival_checks FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.pending_arrival_checks TO service_role;
