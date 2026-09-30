-- Service-role-only store: clients must use the authenticated handlers.
CREATE TABLE IF NOT EXISTS public.home_profiles_v2 (
  address_id bigint PRIMARY KEY REFERENCES public.homeowner_addresses(id) ON DELETE CASCADE,
  user_id bigint NOT NULL REFERENCES public.user_login_agent_details(id),
  profile jsonb NOT NULL DEFAULT '{}'::jsonb
);
ALTER TABLE public.home_profiles_v2 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.home_profiles_v2 FROM anon, authenticated;
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS address_id bigint REFERENCES public.homeowner_addresses(id);
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS system_id text;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('home-profile-documents', 'home-profile-documents', false, 10485760,
 ARRAY['application/pdf','image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;
