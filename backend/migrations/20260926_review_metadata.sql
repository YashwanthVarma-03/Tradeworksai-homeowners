-- Apply before deploying the accompanying website patch.
ALTER TABLE public.contractor_reviews ADD COLUMN IF NOT EXISTS tags jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.contractor_reviews ADD COLUMN IF NOT EXISTS edited_at timestamptz;
ALTER TABLE public.contractor_reviews ADD COLUMN IF NOT EXISTS pro_response jsonb;
-- One response is stored on the original review. Never create a second review
-- or include contractor responses in rating totals.
