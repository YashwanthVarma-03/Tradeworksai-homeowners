"""Inspect by default; --apply applies the companion Stream server policy.

Run only after staging the token handler and updating every website client to
send a verified Supabase bearer token and withUserId before opening a channel.
SDK reference: https://github.com/GetStream/stream-chat-python
Permission model: https://getstream.io/chat/docs/python/chat-permission-policies/
"""
import argparse
import os
import stream_chat


def safe_grants(grants, permissions):
    restricted = {p['id'] for p in permissions if p.get('action', '').lower().startswith(('createchannel', 'addchannelmember', 'updatechannel'))}
    restricted.update({'create-channel', 'create-channel-any-team', 'add-channel-members', 'add-channel-members-owner', 'update-channel', 'update-channel-owner'})
    return {role: values if role in {'admin', 'global_admin'} else [p for p in values if p not in restricted]
            for role, values in grants.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    client = stream_chat.StreamChat(api_key=os.environ['STREAM_API_KEY'], api_secret=os.environ['STREAM_API_SECRET'])
    config = client.get_channel_type('messaging')
    grants = config.get('grants')
    if not isinstance(grants, dict):
        raise RuntimeError('Unable to read messaging grants; no changes made')
    updated = safe_grants(grants, client.list_permissions()['permissions'])
    for role in grants:
        removed = sorted(set(grants[role]) - set(updated[role]))
        if removed:
            print(role, 'remove:', ', '.join(removed))
    if args.apply:
        client.update_channel_type('messaging', grants=updated, read_events=False)
        print('Applied. Test homeowner creation, pro cold-contact rejection, existing replies, and attachments before release.')
    else:
        print('Read-only inspection. Use --apply during coordinated deployment.')


if __name__ == '__main__':
    main()
