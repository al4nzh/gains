DELETE FROM exercises
WHERE is_custom = FALSE AND created_by IS NULL;
