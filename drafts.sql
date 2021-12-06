SELECT u.id AS id14_, u.first_name AS first2_14_,
 u.last_name AS last3_14_, u.street_1 AS street4_14_, u.street_2 AS street5_14_, 
 u.city AS city14_, u.us_state_id AS us7_14_, u.region AS region14_, 
 u.country_id AS country9_14_, u.postal_code AS postal10_14_, u.user_name AS user11_14_, u.password AS password14_, u.profession AS profession14_, u.phone AS phone14_, u.url AS url14_, u.bio AS bio14_, u.last_login AS last17_14_, u.status AS status14_, u.birthdate AS birthdate14_, u.ageinyears AS ageinyears14_, u.deleted AS deleted14_, u.createdate AS createdate14_, u.audit AS audit14_, u.migrated2008 AS migrated24_14_, u.creator AS creator14_
FROM   dir_users u 
WHERE  u.status = 'active'
AND    u.deleted = FALSE





