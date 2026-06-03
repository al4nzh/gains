-- Remove the additional system exercises added in 000024.
DELETE FROM exercises
WHERE is_custom = FALSE
  AND lower(name) IN (
    lower('Decline Bench Press'),
    lower('Machine Chest Press'),
    lower('Dumbbell Fly'),
    lower('Straight-Arm Pulldown'),
    lower('Machine Pulldown'),
    lower('Shrug'),
    lower('Hack Squat'),
    lower('Smith Squat'),
    lower('Goblet Squat'),
    lower('Good Morning'),
    lower('Glute Bridge'),
    lower('Step Up'),
    lower('Seated Leg Curl'),
    lower('Seated Calf Raise'),
    lower('Standing Calf Raise'),
    lower('Machine Shoulder Press'),
    lower('Cable Lateral Raise'),
    lower('Upright Row'),
    lower('EZ Bar Curl'),
    lower('Cable Curl'),
    lower('Incline DB Curl'),
    lower('Rope Triceps Pushdown'),
    lower('Cable Overhead Triceps Extension'),
    lower('Russian Twist'),
    lower('Side Plank')
  );

