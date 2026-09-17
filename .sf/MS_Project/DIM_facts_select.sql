SELECT * FROM dim_student;
SELECT * FROM dim_course;
SELECT * FROM fact_enrollment;


SELECT f.enrollment_key, ds.student_external_id, dc.course_external_id, f.status, f.sync_status
FROM fact_enrollment f
JOIN dim_student ds ON f.student_key = ds.student_key
JOIN dim_course dc ON f.course_key = dc.course_key;