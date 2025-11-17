-- Create reactions table
CREATE TABLE IF NOT EXISTS reactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like', 'love', 'laugh', 'wow', 'sad', 'angry')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, user_id) -- One reaction per user per post
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_reactions_post_id ON reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_reactions_user_id ON reactions(user_id);

-- Enable RLS
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all reactions on public posts
CREATE POLICY "Users can view reactions on public posts"
  ON reactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM posts
      WHERE posts.id = reactions.post_id
      AND posts.is_private = false
    )
  );

-- Policy: Users can view reactions on their own posts
CREATE POLICY "Users can view reactions on their own posts"
  ON reactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM posts
      WHERE posts.id = reactions.post_id
      AND posts.user_id = auth.uid()
    )
  );

-- Policy: Users can view reactions on private posts they have access to
CREATE POLICY "Users can view reactions on private posts they access"
  ON reactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM posts
      WHERE posts.id = reactions.post_id
      AND posts.is_private = true
      AND posts.user_id = auth.uid()
    )
  );

-- Policy: Authenticated users can add reactions
CREATE POLICY "Authenticated users can add reactions"
  ON reactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own reactions
CREATE POLICY "Users can delete their own reactions"
  ON reactions FOR DELETE
  USING (auth.uid() = user_id);

-- Policy: Users can update their own reactions (change reaction type)
CREATE POLICY "Users can update their own reactions"
  ON reactions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
