-- Allow users to have multiple reactions per post (up to 2)

-- First, add custom_emoji column if it doesn't exist
ALTER TABLE reactions 
ADD COLUMN IF NOT EXISTS custom_emoji TEXT;

-- Drop the old unique constraint that limited to 1 reaction per user per post
ALTER TABLE reactions 
DROP CONSTRAINT IF EXISTS reactions_post_id_user_id_key;

-- Add a unique constraint on (post_id, user_id, reaction_type, custom_emoji)
-- This prevents duplicate reactions of the same type
ALTER TABLE reactions
ADD CONSTRAINT reactions_post_user_type_emoji_key 
UNIQUE (post_id, user_id, reaction_type, custom_emoji);

-- Update the check constraint
ALTER TABLE reactions 
DROP CONSTRAINT IF EXISTS reactions_reaction_type_check;

ALTER TABLE reactions 
ADD CONSTRAINT reactions_reaction_type_check 
CHECK (
  reaction_type IN ('like', 'love', 'laugh', 'wow', 'sad', 'angry') 
  OR 
  (reaction_type = 'custom' AND custom_emoji IS NOT NULL)
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_reactions_custom_emoji ON reactions(custom_emoji) 
WHERE custom_emoji IS NOT NULL;

-- Create a function to enforce the 2-reaction limit per user per post
CREATE OR REPLACE FUNCTION check_reaction_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM reactions 
      WHERE post_id = NEW.post_id AND user_id = NEW.user_id) >= 2 THEN
    RAISE EXCEPTION 'User can only have up to 2 reactions per post';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to enforce the limit
DROP TRIGGER IF EXISTS enforce_reaction_limit ON reactions;
CREATE TRIGGER enforce_reaction_limit
  BEFORE INSERT ON reactions
  FOR EACH ROW
  EXECUTE FUNCTION check_reaction_limit();
