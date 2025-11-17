-- add_comment_replies_and_blocking.sql
-- Adds comment replies, user blocking, and threat reporting features

-- 1. Add parent_comment_id to comments table for threaded replies
ALTER TABLE public.comments 
ADD COLUMN IF NOT EXISTS parent_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON public.comments(parent_comment_id);

-- 2. Create blocked_users table
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON public.blocked_users(blocked_id);

-- Enable RLS
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- RLS: Users can only see blocks they created
DROP POLICY IF EXISTS "Users can view own blocks" ON public.blocked_users;
CREATE POLICY "Users can view own blocks" ON public.blocked_users
  FOR SELECT TO authenticated
  USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can create blocks" ON public.blocked_users;
CREATE POLICY "Users can create blocks" ON public.blocked_users
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can delete own blocks" ON public.blocked_users;
CREATE POLICY "Users can delete own blocks" ON public.blocked_users
  FOR DELETE TO authenticated
  USING (auth.uid() = blocker_id);

-- 3. Create threat_reports table for reporting to law enforcement
CREATE TABLE IF NOT EXISTS public.threat_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    threat_type TEXT NOT NULL CHECK (threat_type IN ('physical', 'harassment', 'hate_speech', 'other')),
    description TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'reported_to_law', 'dismissed')),
    law_enforcement_emailed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    reviewed_at TIMESTAMPTZ,
    CHECK (post_id IS NOT NULL OR comment_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_threat_reports_reporter ON public.threat_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_threat_reports_reported_user ON public.threat_reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_threat_reports_status ON public.threat_reports(status);

-- Enable RLS
ALTER TABLE public.threat_reports ENABLE ROW LEVEL SECURITY;

-- RLS: Users can view their own reports
DROP POLICY IF EXISTS "Users can view own reports" ON public.threat_reports;
CREATE POLICY "Users can view own reports" ON public.threat_reports
  FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Users can create reports" ON public.threat_reports;
CREATE POLICY "Users can create reports" ON public.threat_reports
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

-- 4. Update posts RLS to exclude blocked users' content
DROP POLICY IF EXISTS "posts_select_with_privacy" ON public.posts;
CREATE POLICY "posts_select_with_privacy" ON public.posts
  FOR SELECT TO authenticated
  USING (
    -- User's own posts
    auth.uid() = user_id
    OR
    -- Public posts from users who haven't been blocked
    (is_private = false AND NOT EXISTS (
      SELECT 1 FROM public.blocked_users 
      WHERE blocker_id = auth.uid() AND blocked_id = user_id
    ))
  );

-- 5. Update comments RLS to exclude blocked users' comments
DROP POLICY IF EXISTS "comments_select_all" ON public.comments;
CREATE POLICY "comments_select_with_blocking" ON public.comments
  FOR SELECT TO authenticated
  USING (
    -- User's own comments
    auth.uid() = user_id
    OR
    -- Comments from users who haven't been blocked
    NOT EXISTS (
      SELECT 1 FROM public.blocked_users 
      WHERE blocker_id = auth.uid() AND blocked_id = user_id
    )
  );

-- 6. Create function to send email notifications for threat reports
CREATE OR REPLACE FUNCTION public.notify_law_enforcement_threat()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- This trigger can be extended to use Supabase Edge Functions
  -- to send emails via SendGrid, AWS SES, etc.
  -- For now, we just mark it as pending
  NEW.law_enforcement_emailed := false;
  NEW.status := 'pending';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS threat_report_notification ON public.threat_reports;
CREATE TRIGGER threat_report_notification
  BEFORE INSERT ON public.threat_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_law_enforcement_threat();

-- End of add_comment_replies_and_blocking.sql
