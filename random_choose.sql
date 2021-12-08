--choose random from an choosen array value.
CREATE or replace FUNCTION public.random_pick()
  RETURNS int AS
$func$
DECLARE
--    a int[] := '{[0:4]=1,3,7,11,13}'; -- sample sake
     a int[4] := '{1,3,7,11,13}'; -- sample sake
BEGIN
   RETURN a[floor((random()*5))::int];
END
$func$ LANGUAGE plpgsql VOLATILE;
-- 0.0 <= x < 1

select random_pick();
--execute an command multi times, in here it's 10.
select 'select random_pick();' from generate_series(1,10) \gexec