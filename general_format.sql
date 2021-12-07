--genreral format of IF clause in plpgsql
BEGIN
  IF EXISTS(SELECT name FROM test_table t   WHERE t.id = x AND t.name = 'test')
  THEN
     ---
  ELSE
     ---
  END IF;
end