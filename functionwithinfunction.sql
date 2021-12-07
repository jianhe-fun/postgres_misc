
CREATE OR REPLACE FUNCTION get_test(OUT x text, OUT y text)
AS $$
BEGIN
   x := 1;
   y := 2;
END;
$$  LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_test_read()
RETURNS VOID AS $$
DECLARE
   xx text;
   yy text;
BEGIN
   SELECT x,y from get_test() INTO xx, yy;
   RAISE INFO 'x: <%>', xx;
   RAISE INFO 'y: <%>', yy;

END;
$$  LANGUAGE plpgsql;

----------results---------
postgres=# select * from get_test_read();
INFO:  x: <1>
INFO:  y: <2>
 get_test_read
---------------

(1 row)

