-- Add emoji column to reactions table to support custom reactions
ALTER TABLE reactions 
ADD COLUMN IF NOT EXISTS custom_emoji TEXT;

-- Update the constraint to allow any text for reaction_type (for custom reactions)
ALTER TABLE reactions 
DROP CONSTRAINT IF EXISTS reactions_reaction_type_check;

-- Add new constraint that allows predefined reactions OR custom reactions
ALTER TABLE reactions 
ADD CONSTRAINT reactions_reaction_type_check 
CHECK (
  reaction_type IN ('like', 'love', 'laugh', 'wow', 'sad', 'angry') 
  OR 
  (reaction_type = 'custom' AND custom_emoji IS NOT NULL)
);

-- Create index for better performance on custom emoji lookups
CREATE INDEX IF NOT EXISTS idx_reactions_custom_emoji ON reactions(custom_emoji) 
WHERE custom_emoji IS NOT NULL;
