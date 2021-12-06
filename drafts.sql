
CREATE TABLE user (id int, school_id int, name varchar(32));

CREATE TYPE my_type AS (
  user1_id   int,
  user1_name varchar(32),
  user2_id   int,
  user2_name varchar(32)
);

CREATE OR REPLACE FUNCTION get_two_users_from_school(schoolid int)
  RETURNS my_type AS $$
DECLARE
  result my_type;
  temp_result user;
BEGIN
  -- for purpose of this question assume 2 rows returned
  SELECT id, name INTO temp_result FROM user where school_id = schoolid LIMIT 2;
  -- Will the (pseudo)code below work?:
  result.user1_id := temp_result[0].id ;
  result.user1_name := temp_result[0].name ;
  result.user2_id := temp_result[1].id ;
  result.user2_name := temp_result[1].name ;
  return result ;
END
$$ language plpgsql