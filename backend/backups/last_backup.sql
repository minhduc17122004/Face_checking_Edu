--
-- PostgreSQL database dump
--

\restrict MwZMFnkigbLGiqEd5AdiRFKecwcjQLBq393iuvPHU8hLWf2kakSWP5e5sGNVygp

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: vedura
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO vedura;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: vedura
--

COMMENT ON SCHEMA public IS '';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.alembic_version (
    version_num character varying(64) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO vedura;

--
-- Name: attendance; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.attendance (
    id uuid NOT NULL,
    session_id uuid NOT NULL,
    student_id integer NOT NULL,
    checkin_time timestamp with time zone NOT NULL,
    status character varying(20) NOT NULL,
    confidence double precision,
    device_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sync_time timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_attendance_status CHECK (((status)::text = ANY ((ARRAY['present'::character varying, 'late'::character varying, 'absent'::character varying])::text[])))
);


ALTER TABLE public.attendance OWNER TO vedura;

--
-- Name: attendance_audit_logs; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.attendance_audit_logs (
    id uuid NOT NULL,
    student_id integer NOT NULL,
    session_id uuid NOT NULL,
    device_id uuid,
    action character varying(20) NOT NULL,
    old_status character varying(20),
    new_status character varying(20),
    minutes_diff integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.attendance_audit_logs OWNER TO vedura;

--
-- Name: attendance_configs; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.attendance_configs (
    id uuid NOT NULL,
    session_id uuid NOT NULL,
    early_allowance integer NOT NULL,
    late_allowance integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.attendance_configs OWNER TO vedura;

--
-- Name: course_enrollments; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.course_enrollments (
    id uuid NOT NULL,
    student_id integer NOT NULL,
    enrolled_at timestamp with time zone DEFAULT now() NOT NULL,
    course_id uuid NOT NULL
);


ALTER TABLE public.course_enrollments OWNER TO vedura;

--
-- Name: courses; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.courses (
    id uuid NOT NULL,
    course_name character varying(255) NOT NULL,
    subject character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    course_code character varying(50),
    created_by uuid,
    updated_by uuid,
    attendance_mode character varying(20) NOT NULL,
    attendance_before_minutes integer NOT NULL,
    attendance_after_minutes integer NOT NULL,
    department_id uuid,
    room_id uuid,
    teacher_id integer,
    CONSTRAINT ck_courses_attendance_mode CHECK (((attendance_mode)::text = ANY ((ARRAY['preset'::character varying, 'flexible'::character varying, 'custom'::character varying])::text[])))
);


ALTER TABLE public.courses OWNER TO vedura;

--
-- Name: departments; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.departments (
    id uuid NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid
);


ALTER TABLE public.departments OWNER TO vedura;

--
-- Name: device_requests; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.device_requests (
    id uuid NOT NULL,
    device_code character varying(50) NOT NULL,
    device_name character varying(100),
    room_id uuid,
    requested_by uuid,
    status character varying(20) NOT NULL,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    admin_note character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.device_requests OWNER TO vedura;

--
-- Name: devices; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.devices (
    id uuid NOT NULL,
    device_name character varying(100),
    device_type character varying(50) NOT NULL,
    is_active boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_active_at timestamp with time zone,
    ip_address character varying(45),
    deleted_at timestamp with time zone,
    mac_address character varying(17),
    device_code character varying(50) NOT NULL,
    created_by uuid,
    updated_by uuid,
    room_id uuid
);


ALTER TABLE public.devices OWNER TO vedura;

--
-- Name: face_embeddings; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.face_embeddings (
    id uuid NOT NULL,
    student_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    device_id uuid,
    is_active boolean NOT NULL,
    quality_score double precision,
    captured_at timestamp with time zone DEFAULT now() NOT NULL,
    embedding json NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.face_embeddings OWNER TO vedura;

--
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.refresh_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_jti character varying(64) NOT NULL,
    device_id character varying(255),
    expires_at timestamp with time zone NOT NULL,
    revoked boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    device_info jsonb
);


ALTER TABLE public.refresh_tokens OWNER TO vedura;

--
-- Name: rooms; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.rooms (
    id uuid NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    building character varying(100),
    floor integer,
    capacity integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT ck_rooms_code_not_empty CHECK (((code)::text <> ''::text))
);


ALTER TABLE public.rooms OWNER TO vedura;

--
-- Name: schedules; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.schedules (
    id uuid NOT NULL,
    course_id uuid NOT NULL,
    day_of_week integer NOT NULL,
    time_slot_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT ck_day_of_week CHECK (((day_of_week >= 1) AND (day_of_week <= 7)))
);


ALTER TABLE public.schedules OWNER TO vedura;

--
-- Name: sessions; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.sessions (
    id uuid NOT NULL,
    course_id uuid NOT NULL,
    schedule_id uuid,
    status character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone,
    checkin_window_start timestamp with time zone,
    checkin_window_end timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    session_date date NOT NULL,
    CONSTRAINT ck_session_status CHECK (((status)::text = ANY ((ARRAY['scheduled'::character varying, 'active'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT ck_session_status_db CHECK (((status)::text = ANY ((ARRAY['scheduled'::character varying, 'active'::character varying, 'closed'::character varying])::text[])))
);


ALTER TABLE public.sessions OWNER TO vedura;

--
-- Name: student_groups; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.student_groups (
    id uuid NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255),
    advisor_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    department_id uuid
);


ALTER TABLE public.student_groups OWNER TO vedura;

--
-- Name: students; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.students (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    pin character varying(10),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    student_group_id uuid,
    deleted_at timestamp with time zone,
    student_code character varying(50),
    created_by uuid,
    updated_by uuid
);


ALTER TABLE public.students OWNER TO vedura;

--
-- Name: students_id_seq; Type: SEQUENCE; Schema: public; Owner: vedura
--

CREATE SEQUENCE public.students_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.students_id_seq OWNER TO vedura;

--
-- Name: students_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vedura
--

ALTER SEQUENCE public.students_id_seq OWNED BY public.students.id;


--
-- Name: teachers; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.teachers (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    teacher_id character varying(50),
    phone character varying(20),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    department_id uuid
);


ALTER TABLE public.teachers OWNER TO vedura;

--
-- Name: teachers_id_seq; Type: SEQUENCE; Schema: public; Owner: vedura
--

CREATE SEQUENCE public.teachers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teachers_id_seq OWNER TO vedura;

--
-- Name: teachers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vedura
--

ALTER SEQUENCE public.teachers_id_seq OWNED BY public.teachers.id;


--
-- Name: time_slots; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.time_slots (
    id integer NOT NULL,
    period_number integer NOT NULL,
    start_time time with time zone NOT NULL,
    end_time time with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.time_slots OWNER TO vedura;

--
-- Name: time_slots_id_seq; Type: SEQUENCE; Schema: public; Owner: vedura
--

CREATE SEQUENCE public.time_slots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.time_slots_id_seq OWNER TO vedura;

--
-- Name: time_slots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vedura
--

ALTER SEQUENCE public.time_slots_id_seq OWNED BY public.time_slots.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    full_name character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    avatar_url character varying(500),
    deleted_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO vedura;

--
-- Name: students id; Type: DEFAULT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students ALTER COLUMN id SET DEFAULT nextval('public.students_id_seq'::regclass);


--
-- Name: teachers id; Type: DEFAULT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers ALTER COLUMN id SET DEFAULT nextval('public.teachers_id_seq'::regclass);


--
-- Name: time_slots id; Type: DEFAULT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.time_slots ALTER COLUMN id SET DEFAULT nextval('public.time_slots_id_seq'::regclass);


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.alembic_version (version_num) FROM stdin;
fc7a550c7bb0
\.


--
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.attendance (id, session_id, student_id, checkin_time, status, confidence, device_id, created_at, sync_time, deleted_at) FROM stdin;
\.


--
-- Data for Name: attendance_audit_logs; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.attendance_audit_logs (id, student_id, session_id, device_id, action, old_status, new_status, minutes_diff, created_at) FROM stdin;
\.


--
-- Data for Name: attendance_configs; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.attendance_configs (id, session_id, early_allowance, late_allowance, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: course_enrollments; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.course_enrollments (id, student_id, enrolled_at, course_id) FROM stdin;
26e89542-e37c-4c18-be79-bd99e4542195	1	2026-03-23 16:05:52.282149+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
90599bc0-655a-41a9-9cd8-6cc112cb9600	4	2026-03-23 16:05:52.299994+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
a515b881-df10-4a90-9557-b7e5e4926781	2	2026-03-23 16:05:52.303615+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
c1a12d3c-fab4-4fc3-a305-3f42fe6dd14d	7	2026-03-23 16:05:52.307158+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
c85ed736-b2fa-435e-b8f7-0dd3794bd25c	9	2026-03-23 16:05:52.30983+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
ff954fec-d0ec-459f-8206-b2c49db2e039	5	2026-03-23 16:05:52.312803+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
6cd7ac98-79b6-4b60-99bf-5cbfb918d7de	6	2026-03-23 16:05:52.315959+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
7bb9bc62-8ec9-4cdf-a7d5-ecff75731bf5	8	2026-03-23 16:05:52.319684+00	adb5a242-bb03-4597-ba12-976a4b2f4b12
a4847e68-bcde-4083-a3b0-f110ad9a6d0a	1	2026-03-23 16:17:37.48234+00	fbe53de1-2e6f-4063-b940-dd49126681ba
52d7e33c-40ef-4e07-bf35-d4bda6c92d4d	4	2026-03-23 16:17:37.48987+00	fbe53de1-2e6f-4063-b940-dd49126681ba
edc4a937-0acd-4111-80dc-ec69ffba2926	2	2026-03-23 16:17:37.493684+00	fbe53de1-2e6f-4063-b940-dd49126681ba
8dce4b24-9ce6-4ff4-8fe1-07cdd3d71945	7	2026-03-23 16:17:37.496443+00	fbe53de1-2e6f-4063-b940-dd49126681ba
6c88a043-57ff-4854-8601-18bfaae17dad	9	2026-03-23 16:17:37.499534+00	fbe53de1-2e6f-4063-b940-dd49126681ba
7894a5d9-88e8-4b8e-8b71-b807ce772024	5	2026-03-23 16:17:37.50199+00	fbe53de1-2e6f-4063-b940-dd49126681ba
9a654ad3-1812-4206-bdc5-fbbc404c76a8	6	2026-03-23 16:17:37.505726+00	fbe53de1-2e6f-4063-b940-dd49126681ba
68478e14-cf2f-4f13-9225-9b2b7e5a95a3	8	2026-03-23 16:17:37.510003+00	fbe53de1-2e6f-4063-b940-dd49126681ba
f67d9ae9-d42b-4c39-885d-21b165be796e	1	2026-03-23 16:20:48.920458+00	f1c71f4d-96f6-4217-ae1c-4530a68b8bb3
27e387c7-6d9b-4b11-812b-f2ccf8ddf9ed	4	2026-03-23 16:20:48.930315+00	f1c71f4d-96f6-4217-ae1c-4530a68b8bb3
8ebdb02c-ae52-497f-8f9b-63fd9b202b11	2	2026-03-23 16:20:48.93545+00	f1c71f4d-96f6-4217-ae1c-4530a68b8bb3
a35bab74-0d82-4441-a6a9-351501d61d21	5	2026-03-23 16:20:48.939232+00	f1c71f4d-96f6-4217-ae1c-4530a68b8bb3
62ee8caa-6c21-46a4-9c28-bb54d9b6e609	6	2026-03-23 16:20:48.942419+00	f1c71f4d-96f6-4217-ae1c-4530a68b8bb3
0db108a4-a3b0-4237-aa1e-21bf6208583f	1	2026-03-24 04:42:15.440569+00	3078abf6-278b-4409-b544-94eff0cf27df
ba0ab779-d3d6-4694-82ea-7194a20f7d76	4	2026-03-24 04:42:15.455145+00	3078abf6-278b-4409-b544-94eff0cf27df
c4c8a340-8991-4548-b51c-e4920ee3aaf4	2	2026-03-24 04:42:15.457601+00	3078abf6-278b-4409-b544-94eff0cf27df
fa9979ba-c57b-4f91-94eb-b3390c998827	7	2026-03-24 04:42:15.459962+00	3078abf6-278b-4409-b544-94eff0cf27df
62e88b4d-3b12-4ae6-98c0-d2aabb560bd2	9	2026-03-24 04:42:15.462188+00	3078abf6-278b-4409-b544-94eff0cf27df
81107f75-b1f2-4f03-a5cd-bfcff4d6799c	5	2026-03-24 04:42:15.464434+00	3078abf6-278b-4409-b544-94eff0cf27df
38130ef4-76bd-4cc5-affb-7886cf16e6a6	6	2026-03-24 04:42:15.466832+00	3078abf6-278b-4409-b544-94eff0cf27df
eb0b693b-401a-4783-9a63-b115b9616b4b	8	2026-03-24 04:42:15.469188+00	3078abf6-278b-4409-b544-94eff0cf27df
\.


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.courses (id, course_name, subject, created_at, updated_at, deleted_at, course_code, created_by, updated_by, attendance_mode, attendance_before_minutes, attendance_after_minutes, department_id, room_id, teacher_id) FROM stdin;
921a2653-b1cb-404c-86aa-37de2a47ab7c	LT OOP	\N	2026-03-23 13:19:45.228454+00	2026-03-23 13:54:21.041978+00	2026-03-23 13:54:21.038792+00	OOP	\N	\N	preset	30	30	9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523	d7e7c387-5acf-4e4d-b06b-a23467983191	2
79f73d90-afbb-4019-9fde-ee383e4fc686	Luật kinh doann	\N	2026-03-23 13:55:04.442983+00	2026-03-23 13:55:04.442987+00	\N	LAW01	\N	\N	flexible	30	30	c1f3ae5b-1559-4968-abef-a3aef44ef832	d7e7c387-5acf-4e4d-b06b-a23467983191	5
5237abb1-d881-4d17-9e09-2b1ec353c6e9	Cơ sở lập trình	\N	2026-03-23 13:13:00.228125+00	2026-03-23 13:55:49.742976+00	2026-03-23 13:55:49.742204+00	CSLT	\N	\N	preset	30	30	8110f384-f41b-4f6e-84cf-1874852a2a19	6ae854b0-1c85-4147-b839-ad3a1cf56922	4
adb5a242-bb03-4597-ba12-976a4b2f4b12	Test	\N	2026-03-23 14:00:47.250497+00	2026-03-23 14:00:47.250502+00	\N	A	\N	\N	preset	30	30	a6c2c983-6cd6-4cbb-b402-ba1a18fd1ab2	d7e7c387-5acf-4e4d-b06b-a23467983191	1
3078abf6-278b-4409-b544-94eff0cf27df	test1	\N	2026-03-23 14:03:18.409401+00	2026-03-23 14:03:18.409405+00	\N	test	\N	\N	preset	30	30	9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523	d7e7c387-5acf-4e4d-b06b-a23467983191	2
6721380d-c528-45ba-ae7f-3fea28223c4a	e	\N	2026-03-23 14:07:59.874531+00	2026-03-23 14:08:51.53509+00	2026-03-23 14:08:51.534325+00	d	\N	\N	preset	30	30	2e727237-931f-411a-ac44-f94b3e653eb5	d7e7c387-5acf-4e4d-b06b-a23467983191	3
fe970ece-85b4-40dc-8766-fe532be568d6	a	\N	2026-03-23 14:06:47.628822+00	2026-03-23 14:08:54.440022+00	2026-03-23 14:08:54.439135+00	b	\N	\N	preset	30	30	9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523	d7e7c387-5acf-4e4d-b06b-a23467983191	2
f1c71f4d-96f6-4217-ae1c-4530a68b8bb3	e	\N	2026-03-23 14:10:11.655271+00	2026-03-23 14:13:38.756899+00	\N	d	\N	\N	preset	30	30	2e727237-931f-411a-ac44-f94b3e653eb5	6ae854b0-1c85-4147-b839-ad3a1cf56922	3
fbe53de1-2e6f-4063-b940-dd49126681ba	j	\N	2026-03-23 14:14:03.721697+00	2026-03-23 14:14:03.721701+00	\N	b	\N	\N	preset	30	30	2e727237-931f-411a-ac44-f94b3e653eb5	d7e7c387-5acf-4e4d-b06b-a23467983191	3
83c2ae1b-795d-4a4f-94d9-9a8af7079df1	Điểm danh thứ 3	\N	2026-03-24 05:47:02.053105+00	2026-03-24 05:47:02.053113+00	\N	T3	\N	\N	flexible	30	30	a6c2c983-6cd6-4cbb-b402-ba1a18fd1ab2	d7e7c387-5acf-4e4d-b06b-a23467983191	1
55a06610-7bfd-4ab3-b277-f6c2ab611754	Điểm danh thứ 4	\N	2026-03-24 05:47:55.769338+00	2026-03-24 05:47:55.769344+00	\N	T4	\N	\N	flexible	30	30	a6c2c983-6cd6-4cbb-b402-ba1a18fd1ab2	402d2280-93f4-4c8f-89ff-8605db02787e	1
9472af2f-94b2-47e6-8b22-f60449fc1110	LT OOP	\N	2026-03-23 13:18:14.424765+00	2026-03-24 05:49:03.563929+00	2026-03-24 05:49:03.548482+00	OOP	\N	\N	flexible	30	30	9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523	d7e7c387-5acf-4e4d-b06b-a23467983191	2
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.departments (id, code, name, created_at, updated_at, deleted_at, created_by, updated_by) FROM stdin;
2e727237-931f-411a-ac44-f94b3e653eb5	K20	Kinh Tế	2026-03-22 10:21:41.626489+00	2026-03-22 10:21:41.626497+00	\N	\N	\N
3c680997-c5d8-45c4-8474-1487d482520c	K15	Tài chính - Ngân Hàng	2026-03-22 10:23:48.111736+00	2026-03-22 10:24:11.254618+00	2026-03-22 10:24:11.252373+00	\N	\N
8110f384-f41b-4f6e-84cf-1874852a2a19	K29	Thương Mại Điện Tử	2026-03-22 10:18:10.401921+00	2026-03-22 10:40:47.151264+00	\N	\N	\N
9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523	MIS1	Hệ thống thông tin quản lý	2026-03-23 04:04:48.430502+00	2026-03-23 04:04:48.430507+00	\N	\N	\N
c1f3ae5b-1559-4968-abef-a3aef44ef832	LAW01	Luật	2026-03-23 05:34:18.423899+00	2026-03-23 05:34:18.423905+00	\N	\N	\N
a6c2c983-6cd6-4cbb-b402-ba1a18fd1ab2	CNTT	Cơ sở lập trình	2026-03-21 16:33:32.395815+00	2026-03-23 05:35:28.578555+00	\N	\N	\N
\.


--
-- Data for Name: device_requests; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.device_requests (id, device_code, device_name, room_id, requested_by, status, reviewed_by, reviewed_at, admin_note, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.devices (id, device_name, device_type, is_active, created_at, updated_at, last_active_at, ip_address, deleted_at, mac_address, device_code, created_by, updated_by, room_id) FROM stdin;
\.


--
-- Data for Name: face_embeddings; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.face_embeddings (id, student_id, created_at, updated_at, device_id, is_active, quality_score, captured_at, embedding, deleted_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.refresh_tokens (id, user_id, token_jti, device_id, expires_at, revoked, created_at, device_info) FROM stdin;
d27ce645-7ae7-4bf5-9300-1f2cecd61819	19c0116c-3b56-484e-a567-e0289afcf8a0	52dc55f8-d084-4936-b97d-9b0ffc561228	\N	2026-03-27 11:57:32+00	t	2026-03-20 11:57:33.00441+00	\N
76b77ea1-ef39-4ae9-8137-3ecc33cca46e	19c0116c-3b56-484e-a567-e0289afcf8a0	034da5ac-ffe3-4b83-8be8-9f685f49f46c	\N	2026-03-27 12:04:37+00	t	2026-03-20 12:04:37.030823+00	\N
d4779944-ad52-4163-a732-26c7a63b8edc	19c0116c-3b56-484e-a567-e0289afcf8a0	84792692-04ff-4ca2-9997-5f1dc37b18b8	\N	2026-03-27 12:07:47+00	t	2026-03-20 12:07:47.693086+00	\N
36a39bc3-93ae-484d-8810-dadbb50d90dc	23eb02ba-fc39-44d3-b2fb-db6f8a756395	f85368ef-69af-4f72-b080-9c409afcabe5	\N	2026-03-27 12:08:59+00	t	2026-03-20 12:08:59.460188+00	\N
9661e649-626f-42f2-b719-40b0f4a902f7	42597432-1bd8-4d5c-8706-7596293c5887	45c6d4fc-76e3-412c-94eb-c173bb563296	\N	2026-03-27 12:10:34+00	t	2026-03-20 12:10:34.217765+00	\N
b56fcc15-1c7c-4bf0-b3d8-fe43f1921d62	33527004-6529-4cf8-a889-3326fd774bc6	73c20cf0-d2fc-4be8-b480-af98634e850a	\N	2026-03-27 12:27:47+00	f	2026-03-20 12:27:47.269409+00	\N
0ddf229e-d1bd-4943-a43b-e90d1b557ff6	327ecef7-06a8-4cb3-a0fd-143a6436ebbe	7211b59b-d2b8-4b7b-9689-2537325b4294	\N	2026-03-27 12:32:58+00	f	2026-03-20 12:32:58.567349+00	\N
28379f9f-af34-4a61-a7de-8eab9345bff4	19c0116c-3b56-484e-a567-e0289afcf8a0	55f10e28-dba9-4659-9376-42d6f8454a33	\N	2026-03-27 12:10:44+00	t	2026-03-20 12:10:44.470943+00	\N
04f219f9-06bd-4028-aeb7-ea63078aa325	19c0116c-3b56-484e-a567-e0289afcf8a0	539999f3-d516-456b-b02d-76fa10da80fa	\N	2026-03-27 13:05:23+00	t	2026-03-20 13:05:24.001444+00	\N
05d0b5d4-98eb-4b10-a482-e4a4031ccf9f	19c0116c-3b56-484e-a567-e0289afcf8a0	90e4a212-39fd-4e65-9d6e-4d8a836e8078	\N	2026-03-27 17:13:46+00	t	2026-03-20 17:13:46.798831+00	\N
508a91c4-fbee-40ec-9557-a14de0aa98f6	19c0116c-3b56-484e-a567-e0289afcf8a0	604b1e78-207b-4736-a9f1-01b1e032c800	\N	2026-03-28 04:46:44+00	t	2026-03-21 04:46:44.444208+00	\N
7a5b47cc-aacb-4dd4-bcb8-74a9a435fdfc	19c0116c-3b56-484e-a567-e0289afcf8a0	cd525d2c-b6b8-4db9-889c-c40f3b9363e7	\N	2026-03-28 04:38:03+00	t	2026-03-21 04:38:03.171739+00	\N
998ecffe-13b3-42bc-a930-eac3ca217908	19c0116c-3b56-484e-a567-e0289afcf8a0	4e8c1e86-2974-4cfd-80d8-9cc23f613d79	\N	2026-03-28 03:45:49+00	t	2026-03-21 03:45:49.453558+00	\N
a07e48b9-a8f2-404f-8d7e-81d6a9ccb438	19c0116c-3b56-484e-a567-e0289afcf8a0	65bd65c7-b771-4499-9b30-ac5adf4a68f6	\N	2026-03-27 17:50:15+00	t	2026-03-20 17:50:15.876287+00	\N
e64198c6-b5fe-4651-932b-8f6f6739d675	19c0116c-3b56-484e-a567-e0289afcf8a0	5a267805-5e13-4333-bcbb-af3abda387e7	\N	2026-03-28 03:36:51+00	t	2026-03-21 03:36:51.817974+00	\N
1e75ae6a-3e0d-49be-a77e-b258895bc27b	4cf3005c-9790-4d53-995c-a3121ce6c945	590210f5-a2ee-4cfc-b1d3-c401dc3ae963	\N	2026-03-28 04:47:14+00	t	2026-03-21 04:47:14.170302+00	\N
eea3e2cb-e61e-4baa-a948-7733c24ee458	4cf3005c-9790-4d53-995c-a3121ce6c945	7a5fc1a5-99cc-4faa-ad20-b77c645865b6	\N	2026-03-28 03:57:19+00	t	2026-03-21 03:57:19.290126+00	\N
b5676afb-0471-491d-9dc1-0f9425fdf33a	42597432-1bd8-4d5c-8706-7596293c5887	d70ac62d-7f89-4cdc-b6ff-b8c46e600f88	\N	2026-03-28 05:24:27+00	t	2026-03-21 05:24:27.605159+00	\N
2378c130-472f-4581-8fc0-f44d1c48b05e	3e4a9a4f-4f01-4018-9f40-61ec31685b33	6f1ddddf-1ba4-445c-80d7-43cb96df8fa0	\N	2026-03-27 12:33:40+00	t	2026-03-20 12:33:40.470022+00	\N
2a6f69c4-f964-48ab-97e0-851c8e0f8077	3e4a9a4f-4f01-4018-9f40-61ec31685b33	35875f8f-fdb6-4092-9e9e-146cfa5c32f8	\N	2026-03-28 04:48:30+00	t	2026-03-21 04:48:30.107109+00	\N
ca1cc669-6312-4df2-869d-68606b347a22	3e4a9a4f-4f01-4018-9f40-61ec31685b33	7bb6e115-6a87-4589-8974-c90c9c834665	\N	2026-03-28 05:34:37+00	t	2026-03-21 05:34:37.084008+00	\N
d5e69ef0-c5e5-4dbe-a1de-e129acefc868	3e4a9a4f-4f01-4018-9f40-61ec31685b33	10850807-3840-4ce2-bde8-9af69d0f96fa	\N	2026-03-27 12:58:21+00	t	2026-03-20 12:58:22.011855+00	\N
e272656b-d63e-42b1-af96-2b4acce4b899	3e4a9a4f-4f01-4018-9f40-61ec31685b33	f961be29-7e2a-4647-b371-75bdc8615790	\N	2026-03-28 05:24:22+00	t	2026-03-21 05:24:22.203986+00	\N
e49dd37c-451f-4ea9-b3d2-1944619957b5	3e4a9a4f-4f01-4018-9f40-61ec31685b33	ca632dcb-01fa-4792-99fc-ed040999e256	\N	2026-03-27 16:24:50+00	t	2026-03-20 16:24:50.986739+00	\N
ea0db4d5-3ad5-4ac7-99a4-433dbf124548	3e4a9a4f-4f01-4018-9f40-61ec31685b33	c4021194-5c3e-48b8-9fe7-8775cf23d044	\N	2026-03-27 12:28:19+00	t	2026-03-20 12:28:19.882461+00	\N
60c06ca9-6804-47d4-aa13-813476e87aa0	7ee97b58-bed6-44cf-b48e-b16b633994ac	eda18266-444e-4507-b354-e78f0c0c0754	\N	2026-03-27 17:39:50+00	t	2026-03-20 17:39:50.901544+00	\N
ebf9d6ef-c6b8-4bac-b4f8-207b20884fe2	7ee97b58-bed6-44cf-b48e-b16b633994ac	360466ce-b196-4abf-8805-008251908d06	\N	2026-03-28 05:35:47+00	t	2026-03-21 05:35:47.848458+00	\N
6d1ff8fe-bfcc-4de4-b77c-a4a9bc410f07	fc936617-708b-42f0-b26b-dcba946cd2e3	c53a6685-069b-4369-819e-73fe107d4c37	\N	2026-03-27 17:15:45+00	t	2026-03-20 17:15:45.37605+00	\N
77ee52a8-b863-41ec-bbcd-19c8f4f34c2c	fc936617-708b-42f0-b26b-dcba946cd2e3	80fb68af-d52c-4662-b30e-91c863e97bc8	\N	2026-03-28 05:36:16+00	t	2026-03-21 05:36:16.644429+00	\N
35edb7f3-3516-4724-b095-b937e3f1953e	d79eb64f-ac88-4e89-b8b5-8e465352c47e	dd943ad0-18a5-4d38-9e2b-d5df4e27d9be	\N	2026-03-28 05:38:22+00	f	2026-03-21 05:38:22.802942+00	\N
459bbc93-d476-4757-94d3-73f156f93dc9	19c0116c-3b56-484e-a567-e0289afcf8a0	11e3a0ec-6409-41f7-a3cc-35e00e76fa15	\N	2026-03-28 05:37:10+00	t	2026-03-21 05:37:10.847281+00	\N
39a9f060-52a9-4cb0-a2b8-50f1e6ce4537	6b454463-ef8a-4619-98d6-8ec207d543d9	8bf306a8-4332-4f93-b12f-9bf6214eeef8	\N	2026-03-28 05:40:18+00	t	2026-03-21 05:40:18.404943+00	\N
f4d873ff-e88e-4910-a484-fedfdf4d715f	6b454463-ef8a-4619-98d6-8ec207d543d9	d533a702-1351-44dc-804d-c632d254b9ea	\N	2026-03-28 05:41:31+00	t	2026-03-21 05:41:31.253452+00	\N
286ffb70-f41a-41ba-b426-f000a130aede	19c0116c-3b56-484e-a567-e0289afcf8a0	1f58a385-2b60-4ca6-9dcc-72eccc7bb57a	\N	2026-03-28 05:47:28+00	t	2026-03-21 05:47:28.658429+00	\N
3ea7ca4c-38df-43e2-9b90-f793588d7ebf	d26ed111-3809-492b-aede-1937d03080dd	6851fa6f-c5d7-4550-99de-3c706f95f5b5	\N	2026-03-28 05:58:55+00	t	2026-03-21 05:58:55.581599+00	\N
43949b6a-507e-4fc5-a6d0-3cef4b20670d	d26ed111-3809-492b-aede-1937d03080dd	bb10ecdc-8c5a-4117-a653-ba220daf903d	\N	2026-03-28 05:48:45+00	t	2026-03-21 05:48:45.421599+00	\N
e516a2a5-2d56-4f4e-ba0e-1a4cb87d0cc9	19c0116c-3b56-484e-a567-e0289afcf8a0	a608f261-3c00-42eb-97cf-2c9e77ee196c	\N	2026-03-28 06:05:21+00	t	2026-03-21 06:05:21.471335+00	\N
6b2de306-1148-4471-82fc-cc5ceb3ef968	89cae998-821b-4665-bdd7-39a77763c752	8d2552f3-f079-4a5b-90fa-3a9894a27fd2	\N	2026-03-28 06:08:03+00	t	2026-03-21 06:08:03.898401+00	\N
f95744f4-b05c-4079-8602-f44ee8f42175	89cae998-821b-4665-bdd7-39a77763c752	1edbfbb8-6f88-4496-9424-1ae56f5d863c	\N	2026-03-28 06:07:46+00	t	2026-03-21 06:07:46.541194+00	\N
bd4809b0-45e0-4860-ac10-807ee4a3083a	19c0116c-3b56-484e-a567-e0289afcf8a0	abb3000a-0a1f-4341-8a7d-560f5aaac014	\N	2026-03-28 06:11:55+00	t	2026-03-21 06:11:55.630168+00	\N
f9d6020c-9a63-4832-8661-18224567a2ad	4cf3005c-9790-4d53-995c-a3121ce6c945	4aa0324f-c970-4385-855e-8daadb40215e	\N	2026-03-28 06:12:38+00	t	2026-03-21 06:12:38.628736+00	\N
85dea7cc-e5ff-4f8b-b20b-7649b9f06531	19c0116c-3b56-484e-a567-e0289afcf8a0	315393fd-8ead-4905-92ec-ac7662c2fc93	\N	2026-03-28 06:14:25+00	t	2026-03-21 06:14:25.79148+00	\N
ae703af1-5c17-4a91-a6f0-7540e1b50150	19c0116c-3b56-484e-a567-e0289afcf8a0	9312d604-9b88-49ab-86b3-53377bebfa2b	\N	2026-03-28 07:14:45+00	t	2026-03-21 07:14:45.161434+00	\N
c7ba07bb-d139-4203-8902-ef28eec808a8	19c0116c-3b56-484e-a567-e0289afcf8a0	f1fa06f2-adda-400b-895b-c2b4fb119146	\N	2026-03-28 17:00:58+00	t	2026-03-21 17:00:58.961193+00	\N
dbd707be-1444-4ecc-b960-65e270ba722e	19c0116c-3b56-484e-a567-e0289afcf8a0	4a7a60dd-8fda-42a5-ade7-5060102f03df	\N	2026-03-28 17:01:04+00	t	2026-03-21 17:01:04.962463+00	\N
4330217a-8dca-4175-ace9-98a52e2d90a2	23eb02ba-fc39-44d3-b2fb-db6f8a756395	770fd1a1-c1b8-4be8-958a-379597b914f6	\N	2026-03-28 17:02:57+00	t	2026-03-21 17:02:57.139955+00	\N
3819e97b-1933-4e84-bf38-d5800971e00a	42597432-1bd8-4d5c-8706-7596293c5887	90f00c19-ce2a-426d-9b6f-8e7ea004cf14	\N	2026-03-28 17:03:20+00	t	2026-03-21 17:03:20.182069+00	\N
fc3f2659-34e7-43df-82da-4150da9140a5	19c0116c-3b56-484e-a567-e0289afcf8a0	c1b3e5b8-b7b7-4c75-98e0-9c4081e9e5ce	\N	2026-03-28 17:03:37+00	t	2026-03-21 17:03:37.443082+00	\N
220597e7-2cbe-4767-a167-19b7b4621d1b	52ecdf48-6604-4e32-a13c-5b1e2312c8d1	667a9bc0-d653-42b6-aaa6-4cd90f665434	\N	2026-03-28 17:06:07+00	t	2026-03-21 17:06:07.442802+00	\N
fbb237e6-f224-45c4-b77c-222571059333	52ecdf48-6604-4e32-a13c-5b1e2312c8d1	f8102bed-d2a3-4f0c-8103-a78f7d9743b1	\N	2026-03-28 17:05:38+00	t	2026-03-21 17:05:38.450214+00	\N
2a68a59a-eb7f-40ed-8657-03c57a15f9db	19c0116c-3b56-484e-a567-e0289afcf8a0	57900e5e-7964-447d-ad2d-6413264a0036	\N	2026-03-29 05:33:03+00	t	2026-03-22 05:33:03.59164+00	\N
5b33df23-7c69-4d49-89a0-c5cb00a94149	19c0116c-3b56-484e-a567-e0289afcf8a0	3e920207-759a-4766-9f85-98f10b3ee719	\N	2026-03-29 08:02:12+00	t	2026-03-22 08:02:12.217502+00	\N
a60eaf95-13e6-4d25-99a3-535a2b20b6ba	19c0116c-3b56-484e-a567-e0289afcf8a0	f956620d-f06a-440f-a20a-b53866d79a0c	\N	2026-03-29 05:33:03+00	t	2026-03-22 05:33:03.590319+00	\N
bfb57dd3-e9d2-4135-9ecd-5712b754d362	19c0116c-3b56-484e-a567-e0289afcf8a0	5b65cf1a-cb9a-4851-91af-b9ee3736ea16	\N	2026-03-29 05:35:54+00	t	2026-03-22 05:35:54.640216+00	\N
d0070df0-ca9f-4d3c-b3d7-98f8e9619c69	19c0116c-3b56-484e-a567-e0289afcf8a0	41b23818-e265-4d56-9e6f-f2055f7a9588	\N	2026-03-29 08:05:59+00	t	2026-03-22 08:05:59.969854+00	\N
65dc8bbe-4700-43f9-9a98-47fe68c914c4	19c0116c-3b56-484e-a567-e0289afcf8a0	3fad1c78-17c8-4058-b47c-7490d531d885	\N	2026-03-29 08:11:28+00	t	2026-03-22 08:11:28.201098+00	\N
ce5e44d2-6c52-4878-92d5-539062de2443	19c0116c-3b56-484e-a567-e0289afcf8a0	22fde080-6591-40e9-a4de-f4a450581e40	\N	2026-03-29 08:43:09+00	t	2026-03-22 08:43:09.245806+00	\N
183db4eb-073b-430a-a0e4-729925985198	23eb02ba-fc39-44d3-b2fb-db6f8a756395	77aab0aa-5506-420a-9bbd-d29c43340333	\N	2026-03-29 02:43:20+00	t	2026-03-22 02:43:20.847564+00	\N
921ead79-3550-4795-9a11-e48839e2569a	4cf3005c-9790-4d53-995c-a3121ce6c945	972f6f9f-cee3-4d06-8ac9-e6b5f62596ba	\N	2026-03-28 06:26:03+00	t	2026-03-21 06:26:03.106856+00	\N
b206fa37-038f-4b2d-9949-7095404accd3	24f7e4a4-3da2-4e50-9702-73e91ebee9f3	0b407706-27a0-47ef-9946-56d9f94be930	\N	2026-03-27 12:32:13+00	t	2026-03-20 12:32:13.220624+00	\N
db547eb0-fc7d-4b86-a823-331b1a32a29a	19c0116c-3b56-484e-a567-e0289afcf8a0	6a40b1f2-3508-4e00-b877-b505671b0a09	\N	2026-03-29 08:03:20+00	t	2026-03-22 08:03:20.275071+00	\N
f3304a51-91b3-48da-9999-18a2f93f9a2b	19c0116c-3b56-484e-a567-e0289afcf8a0	5a02671d-2969-4877-9793-e38799291d60	\N	2026-03-28 17:08:27+00	t	2026-03-21 17:08:27.547432+00	\N
ff550206-d1a2-4795-beba-52db209f6357	19c0116c-3b56-484e-a567-e0289afcf8a0	4aea994b-382d-4a0f-9e47-57919a03adae	\N	2026-03-29 05:33:02+00	t	2026-03-22 05:33:03.589766+00	\N
c6be0c12-1017-49e5-8c56-84294eb122c0	19c0116c-3b56-484e-a567-e0289afcf8a0	36247f2e-953d-46d8-9b56-df898e41ef3c	\N	2026-03-29 08:03:57+00	t	2026-03-22 08:03:57.78868+00	\N
c8c865a8-17bf-477e-b194-ada99bbc854f	ba09ea0a-9155-4d30-a7f7-f5a7a47bc599	d117eecf-a944-44e9-9ca7-bb4e3710e0cc	\N	2026-03-30 04:23:06+00	f	2026-03-23 04:23:06.175952+00	\N
0f142c63-e817-4e33-8105-537346fc7adf	19c0116c-3b56-484e-a567-e0289afcf8a0	da7d9c58-bb76-4f9b-8d3f-b216fc95f99b	\N	2026-03-29 09:45:11+00	t	2026-03-22 09:45:11.606951+00	\N
0f173105-de80-480a-aa2c-89991de45c87	19c0116c-3b56-484e-a567-e0289afcf8a0	e2eec3a6-987f-444e-b265-ace138048535	\N	2026-03-30 02:02:15+00	t	2026-03-23 02:02:15.461842+00	\N
29c3f7b9-7857-43d2-9f7d-e7c1e6066656	19c0116c-3b56-484e-a567-e0289afcf8a0	b6646b5e-a641-44f3-a842-e22f6bd7e220	\N	2026-03-29 09:14:42+00	t	2026-03-22 09:14:42.220131+00	\N
3a1a2bd5-7787-4a11-b3a3-fb721ee55c69	19c0116c-3b56-484e-a567-e0289afcf8a0	8f41eb5d-e50a-4626-ab1d-7afdef74da59	\N	2026-03-29 10:17:09+00	t	2026-03-22 10:17:09.220723+00	\N
3d7439c8-cf54-4dd9-94a8-b15a6f7f7794	19c0116c-3b56-484e-a567-e0289afcf8a0	1d167935-9ed1-47b0-8534-2355720f3d82	\N	2026-03-30 01:31:53+00	t	2026-03-23 01:31:53.051134+00	\N
4219b959-15f9-4229-98c4-4308973cb9ec	19c0116c-3b56-484e-a567-e0289afcf8a0	40783839-8224-4079-8f55-a7cc8a80eeef	\N	2026-03-30 04:17:43+00	t	2026-03-23 04:17:43.332202+00	\N
4f360d8b-a7ca-4f47-9362-af160a054a90	19c0116c-3b56-484e-a567-e0289afcf8a0	a2c875d0-250c-4e8d-acd9-b6efd6dfd75d	\N	2026-03-30 00:59:14+00	t	2026-03-23 00:59:14.818394+00	\N
534b7753-4c42-4f23-9722-029155dab5eb	19c0116c-3b56-484e-a567-e0289afcf8a0	ee11f1ab-ef1b-4d63-a264-c4e49484835f	\N	2026-03-29 09:45:20+00	t	2026-03-22 09:45:20.129549+00	\N
56028af4-eb80-4c1e-bb92-2b9682018f89	19c0116c-3b56-484e-a567-e0289afcf8a0	8cacabe9-3b82-4692-9db8-67539a6bded6	\N	2026-03-30 02:33:59+00	t	2026-03-23 02:33:59.761351+00	\N
5f09469a-5283-4f86-9abb-5a8532f87846	19c0116c-3b56-484e-a567-e0289afcf8a0	51e86a9e-f171-49a0-af17-bdd5cfc25ce0	\N	2026-03-29 08:41:43+00	t	2026-03-22 08:41:43.816254+00	\N
711d863d-98a7-4f01-a8e7-ebce46665d93	19c0116c-3b56-484e-a567-e0289afcf8a0	757c0b20-efac-41cb-a767-4bc86fdbf420	\N	2026-03-30 04:17:39+00	t	2026-03-23 04:17:39.926448+00	\N
94311492-402f-419a-b6de-291a09fb85e3	19c0116c-3b56-484e-a567-e0289afcf8a0	29275867-401a-4696-a220-dd9bcc863bb8	\N	2026-03-30 03:17:36+00	t	2026-03-23 03:17:37.003644+00	\N
b9a16a7d-cd5a-47db-917d-10eccb429cc9	19c0116c-3b56-484e-a567-e0289afcf8a0	651e9c57-7685-4d02-9629-84799a49697e	\N	2026-03-29 09:14:55+00	t	2026-03-22 09:14:55.361351+00	\N
bb4e7699-8729-40f3-b6bb-99209562bf5a	19c0116c-3b56-484e-a567-e0289afcf8a0	ed14f0e2-cabb-46bb-867b-7d3b669e451b	\N	2026-03-29 10:16:03+00	t	2026-03-22 10:16:03.255148+00	\N
c049b13c-c757-4019-95ca-bed118937723	19c0116c-3b56-484e-a567-e0289afcf8a0	0fad5fb2-0303-4c82-957f-b5c70086c31c	\N	2026-03-30 02:35:23+00	t	2026-03-23 02:35:23.852662+00	\N
d38a6938-1d40-49f2-9d01-2008e31d42cd	19c0116c-3b56-484e-a567-e0289afcf8a0	56aefe17-958e-46d3-83c8-b2c023294a01	\N	2026-03-30 03:46:02+00	t	2026-03-23 03:46:02.40037+00	\N
d8fe942d-72c0-48c5-a306-c93e39137076	19c0116c-3b56-484e-a567-e0289afcf8a0	04f7dac6-d172-4d74-b631-58dc0e5904c9	\N	2026-03-30 02:02:37+00	t	2026-03-23 02:02:37.281676+00	\N
8f304ac1-82cb-4385-8ec0-1c29cb0e9624	982e7aab-932a-4a97-b774-6f9fb2780ba0	f215962b-076e-43a1-a269-cd03ba8ac17d	\N	2026-03-30 04:32:31+00	t	2026-03-23 04:32:31.819351+00	\N
f00f8d14-7e69-4c9b-b7ca-b85f3d90d0ea	982e7aab-932a-4a97-b774-6f9fb2780ba0	3cf454cc-d06a-4b14-8f9b-71eee41f8c94	\N	2026-03-30 04:31:31+00	t	2026-03-23 04:31:31.153871+00	\N
f2819642-368c-4c84-a250-908587be900f	19c0116c-3b56-484e-a567-e0289afcf8a0	65209ef6-86d3-42de-ad2f-a450b54bbe08	\N	2026-03-30 04:38:07+00	t	2026-03-23 04:38:07.499174+00	\N
147ed0ce-223c-451a-9567-14170bd33af8	42597432-1bd8-4d5c-8706-7596293c5887	bf43947f-8971-4fde-a39f-b454ec7d5336	\N	2026-03-30 04:45:00+00	t	2026-03-23 04:45:00.377314+00	\N
39fe6a7d-e110-4163-98d3-23dece5f5f2e	90eb4bde-f697-48ca-8e45-627ba953a659	26f9242e-97bc-4d58-a4d9-d29a8c705bd9	\N	2026-03-30 04:24:33+00	t	2026-03-23 04:24:33.675645+00	\N
596c5c42-e6e0-4f48-977d-272eb802c6c1	90eb4bde-f697-48ca-8e45-627ba953a659	e945ccdb-71c5-4452-b1a6-1f4924abe643	\N	2026-03-30 04:45:16+00	t	2026-03-23 04:45:16.079107+00	\N
2d55a741-cd84-44c8-8efd-87664d7c57d1	19c0116c-3b56-484e-a567-e0289afcf8a0	274ab3b4-dac2-4771-8431-d9c9e3eb0b50	\N	2026-03-30 04:50:24+00	t	2026-03-23 04:50:24.909506+00	\N
d9200ceb-4b4d-4001-8f7f-d22130d26a71	19c0116c-3b56-484e-a567-e0289afcf8a0	fdd47a14-5596-4435-94d5-0fd5ad613da6	\N	2026-03-30 04:49:50+00	t	2026-03-23 04:49:50.975163+00	\N
fd05097c-8a00-407d-9dca-8998bc384d56	19c0116c-3b56-484e-a567-e0289afcf8a0	f8858da7-ac0f-497c-aceb-2564b9f7abaf	\N	2026-03-30 04:49:22+00	t	2026-03-23 04:49:22.127284+00	\N
2d88001d-6da1-4deb-8ea3-c685185eacee	52ecdf48-6604-4e32-a13c-5b1e2312c8d1	6fba58fd-b360-49c0-958c-fc898f60ea62	\N	2026-03-30 04:52:37+00	t	2026-03-23 04:52:37.478773+00	\N
67b1dd13-4b4c-4b04-8ba0-bbd53f98ecf5	19c0116c-3b56-484e-a567-e0289afcf8a0	4c697c1a-5227-450f-a57b-f855c16c6a7a	\N	2026-03-30 04:53:59+00	t	2026-03-23 04:53:59.621057+00	\N
33e2cef7-9f24-47be-b773-070acc736875	982e7aab-932a-4a97-b774-6f9fb2780ba0	6167fcc4-dd0e-4f6a-ae25-9be236e3e3b4	\N	2026-03-30 05:04:56+00	t	2026-03-23 05:04:56.654096+00	\N
62057ff3-086e-426a-9fec-5b7ee22936fe	19c0116c-3b56-484e-a567-e0289afcf8a0	368dd187-841d-46d2-b680-d8ef689ae246	\N	2026-03-30 05:06:51+00	t	2026-03-23 05:06:51.024237+00	\N
6fbd6c34-fda8-421f-accd-722c307d1853	b90a64ac-289e-4a82-a82a-ec0c1a1cae53	ae7f441e-503c-48f5-a8fc-f793a9e66b9e	\N	2026-03-30 05:09:48+00	t	2026-03-23 05:09:48.166036+00	\N
c0aae9b4-9060-4fdc-a9e4-6d4cd0b23dfc	b90a64ac-289e-4a82-a82a-ec0c1a1cae53	f45c628f-39c2-46f6-9c5b-b9a8cfe99661	\N	2026-03-30 05:09:36+00	t	2026-03-23 05:09:36.034191+00	\N
9ac05295-c5b9-4fd7-b9cc-06050795d3b2	90eb4bde-f697-48ca-8e45-627ba953a659	0d8a7a83-daa1-4510-ae71-4c1a31a95ef0	\N	2026-03-30 05:11:30+00	t	2026-03-23 05:11:30.653887+00	\N
ef2dfe26-6c60-4f5c-b04f-5ecba8081d6c	19c0116c-3b56-484e-a567-e0289afcf8a0	df9b8f54-50a2-4e73-9df3-c2c55f0442b4	\N	2026-03-30 05:12:07+00	t	2026-03-23 05:12:07.038141+00	\N
c8bf0930-8e22-4f56-aea3-7186c5c6bba0	b90a64ac-289e-4a82-a82a-ec0c1a1cae53	ef25f976-b8c0-4187-bd2f-1ff39816630a	\N	2026-03-30 05:17:27+00	t	2026-03-23 05:17:27.086443+00	\N
316872a6-130d-45f4-bda3-e24ce323599a	90eb4bde-f697-48ca-8e45-627ba953a659	9438341e-f9ef-47ed-a3f2-d7ef7575db4f	\N	2026-03-30 05:17:46+00	t	2026-03-23 05:17:46.010597+00	\N
85b7aeb9-b05c-425b-a828-1c6293da9b98	0afb83eb-6159-4d92-ab1b-29383ff0b860	4fca8e8b-9078-4442-b287-61220f4eb5c6	\N	2026-03-30 09:25:03+00	f	2026-03-23 09:25:03.127732+00	\N
6b7d5206-4944-4651-bdba-f12bf4349b42	fb0cef2c-c64c-4694-8385-17c049166aea	ec4bc89e-7a3e-43e9-9856-d98a00cb7d54	\N	2026-03-30 09:26:16+00	f	2026-03-23 09:26:16.701807+00	\N
20fa89b3-4c1c-4db7-999c-30d30c217d49	19c0116c-3b56-484e-a567-e0289afcf8a0	513d019d-bd1a-4ee3-9e2c-82a21302d31b	\N	2026-03-30 09:23:39+00	t	2026-03-23 09:23:39.34731+00	\N
2787e5cc-e695-4dae-b27c-8448af0ba85b	19c0116c-3b56-484e-a567-e0289afcf8a0	30179615-03ec-4e33-bf2a-2dad8138a9e4	\N	2026-03-30 12:08:44+00	t	2026-03-23 12:08:44.07766+00	\N
7445b55f-69bd-495f-9a98-0abe1ca501e5	19c0116c-3b56-484e-a567-e0289afcf8a0	ec1acb7f-7f0f-47ec-9081-430d698da8d4	\N	2026-03-30 05:32:12+00	t	2026-03-23 05:32:12.32181+00	\N
9dde3915-70b3-4cf9-999b-b587b9c89f99	19c0116c-3b56-484e-a567-e0289afcf8a0	90c6ddd8-6219-4894-94f2-52a5bdb99421	\N	2026-03-30 05:16:36+00	t	2026-03-23 05:16:36.495683+00	\N
aba0c645-fa3a-476c-a187-e7c0f71a876e	19c0116c-3b56-484e-a567-e0289afcf8a0	ceb534bd-a852-414e-8d57-d18f3d6d9411	\N	2026-03-30 12:07:35+00	t	2026-03-23 12:07:35.129131+00	\N
b57fea99-6151-4a8e-95e3-5b2ac1856bad	19c0116c-3b56-484e-a567-e0289afcf8a0	e8fe3cb9-b34e-42ee-8f9e-590b0cd36778	\N	2026-03-30 10:22:03+00	t	2026-03-23 10:22:03.616355+00	\N
daaa60d8-906d-4a09-9ac2-84066b844c81	19c0116c-3b56-484e-a567-e0289afcf8a0	21e3712c-9fe1-4852-b936-a030de663325	\N	2026-03-30 11:01:58+00	t	2026-03-23 11:01:58.211424+00	\N
ec358279-1b04-441e-ba26-4034244146e7	19c0116c-3b56-484e-a567-e0289afcf8a0	71eeba43-d1dd-4ede-b0de-a8a1120ba17c	\N	2026-03-30 10:21:57+00	t	2026-03-23 10:21:57.78419+00	\N
eef80d8d-ef6d-4ca4-ac57-b8c203179dc9	19c0116c-3b56-484e-a567-e0289afcf8a0	15ca120b-98d3-4c8d-8dbe-2651e21a371d	\N	2026-03-30 11:02:02+00	t	2026-03-23 11:02:02.991891+00	\N
f562305b-8b56-4433-8df0-d129aa48e0c6	19c0116c-3b56-484e-a567-e0289afcf8a0	a6c66999-a3fe-4a91-9e66-4b379ecd7a37	\N	2026-03-30 09:23:23+00	t	2026-03-23 09:23:23.562424+00	\N
063b030d-3e1b-4d7e-80d5-5b3dfb3337c7	19c0116c-3b56-484e-a567-e0289afcf8a0	4eb13fe0-bd02-4715-9308-0e9bb1eb87e2	\N	2026-03-30 12:09:07+00	t	2026-03-23 12:09:07.643676+00	\N
a51e65ad-8c6c-46a3-b923-28f5007ad644	19c0116c-3b56-484e-a567-e0289afcf8a0	3d8361ba-af05-4fcd-ae58-11ea70e172c0	\N	2026-03-30 12:13:04+00	t	2026-03-23 12:13:04.015133+00	\N
f72b3788-8715-4f26-b12f-4fb19b7f4f13	23eb02ba-fc39-44d3-b2fb-db6f8a756395	1c3cf183-b19b-4fcf-bc2a-a40bec90c600	\N	2026-03-30 12:14:19+00	t	2026-03-23 12:14:19.426369+00	\N
127652a8-34b0-48f4-be44-09dce6b35d54	19c0116c-3b56-484e-a567-e0289afcf8a0	2009251f-8e1b-432c-9cc0-073abf1ac3e7	\N	2026-03-30 12:16:34+00	t	2026-03-23 12:16:34.282426+00	\N
1ae6f9c8-fcc7-4124-9df2-34c8dd1e5fe3	19c0116c-3b56-484e-a567-e0289afcf8a0	78028d6a-2afd-49b9-9ee9-dc404433e529	\N	2026-03-30 13:17:26+00	t	2026-03-23 13:17:26.238354+00	\N
45864566-d9e8-4556-8d2c-ebcb2d0cfb39	19c0116c-3b56-484e-a567-e0289afcf8a0	ad850269-171f-43cf-90fc-a1c94c40cda8	\N	2026-03-30 12:47:10+00	t	2026-03-23 12:47:10.477293+00	\N
63d18480-ff14-4a22-951a-beead419b872	19c0116c-3b56-484e-a567-e0289afcf8a0	6b65ef86-1ac6-4692-9c84-f2c9e13d61ca	\N	2026-03-30 12:47:05+00	t	2026-03-23 12:47:05.397563+00	\N
a227bf00-edcd-4533-a2de-fbe47a6198c3	19c0116c-3b56-484e-a567-e0289afcf8a0	050f26b5-c555-472c-8173-0da4b884e574	\N	2026-03-30 13:49:19+00	t	2026-03-23 13:49:19.16653+00	\N
af716eb1-32c3-41cd-a7ae-d827684f84f3	19c0116c-3b56-484e-a567-e0289afcf8a0	610fbd99-b3e1-44e7-95b0-a59badf9ef12	\N	2026-03-30 13:49:26+00	t	2026-03-23 13:49:26.647822+00	\N
c511382c-8aab-4a1e-9568-154ebc615ff2	19c0116c-3b56-484e-a567-e0289afcf8a0	9067f9f8-00b8-46fc-b27a-5d023a102e41	\N	2026-03-30 13:17:31+00	t	2026-03-23 13:17:31.233904+00	\N
285d7b41-b389-456d-9ead-922f86793b65	23eb02ba-fc39-44d3-b2fb-db6f8a756395	0e501757-7d7c-440d-bf0a-8ecf7a07378b	\N	2026-03-30 13:57:59+00	t	2026-03-23 13:57:59.164524+00	\N
44292894-c5fa-42ed-8674-6c1897a5a067	19c0116c-3b56-484e-a567-e0289afcf8a0	b1e63848-61bc-4723-a252-d4620b1621c0	\N	2026-03-30 13:58:21+00	t	2026-03-23 13:58:21.871471+00	\N
540269f9-9e29-46d4-abca-e508f491f1f2	19c0116c-3b56-484e-a567-e0289afcf8a0	65355480-32f8-4df9-b5e2-73652829d760	\N	2026-03-30 14:04:15+00	t	2026-03-23 14:04:15.148209+00	\N
68013714-6529-454e-acd6-c0791cb5cab6	19c0116c-3b56-484e-a567-e0289afcf8a0	c7150be7-0c60-42be-8c20-dbf1236c2441	\N	2026-03-30 16:01:21+00	t	2026-03-23 16:01:21.478932+00	\N
769f4a83-0d53-4539-8126-f2ac2687067e	19c0116c-3b56-484e-a567-e0289afcf8a0	a3814e47-0bf3-4d69-9551-353dd0306a19	\N	2026-03-30 16:01:18+00	t	2026-03-23 16:01:18.071737+00	\N
9b76ab80-02c5-4002-9197-230dba4f911f	19c0116c-3b56-484e-a567-e0289afcf8a0	4f240f2b-4d53-4b21-9c9f-2ae3fdbe3a33	\N	2026-03-30 15:30:32+00	t	2026-03-23 15:30:32.569832+00	\N
bae709dc-dfd2-4c8f-8acc-3b1d6c52a378	19c0116c-3b56-484e-a567-e0289afcf8a0	3b7d5710-57f9-46ba-9bcc-d9aec083d373	\N	2026-03-30 15:31:08+00	t	2026-03-23 15:31:08.792019+00	\N
147a97c5-7186-4000-bef8-e008f8788984	982e7aab-932a-4a97-b774-6f9fb2780ba0	0ec379b2-11d4-406e-9a45-c2365d030023	\N	2026-03-30 16:26:14+00	t	2026-03-23 16:26:14.833073+00	\N
7eac8431-9c5c-411f-aa36-dcefb11ebd8e	19c0116c-3b56-484e-a567-e0289afcf8a0	1e31a57c-c503-43d9-b1e2-ecd11ee62c30	\N	2026-03-30 16:26:39+00	t	2026-03-23 16:26:39.532345+00	\N
ebd58d61-fb8c-40e2-b9ee-d794e2ff9877	982e7aab-932a-4a97-b774-6f9fb2780ba0	9dcdcabd-febf-4843-8891-4e292212abb2	\N	2026-03-30 16:27:13+00	t	2026-03-23 16:27:13.038706+00	\N
c133a614-34dc-4a55-9183-eb890dee4b86	19c0116c-3b56-484e-a567-e0289afcf8a0	b5ea91a3-b110-4765-b0ab-6b00de973c08	\N	2026-03-30 16:27:24+00	t	2026-03-23 16:27:24.256729+00	\N
439b80cd-da82-41bc-81d3-170daa01fd32	90eb4bde-f697-48ca-8e45-627ba953a659	20df8fba-5b91-4b1d-8fc6-f701d5fbfe45	\N	2026-03-30 16:27:42+00	t	2026-03-23 16:27:42.25716+00	\N
16982ece-28f9-4290-bcb8-27c3f96710f7	19c0116c-3b56-484e-a567-e0289afcf8a0	45da45ef-0e04-48f8-82b4-a8def25e80f9	\N	2026-03-31 04:19:05+00	t	2026-03-24 04:19:05.536685+00	\N
41f076ed-ea16-4973-881f-c006a50551d9	19c0116c-3b56-484e-a567-e0289afcf8a0	d443d8f1-1ff5-4850-9f94-f97d343c4060	\N	2026-03-31 04:19:42+00	t	2026-03-24 04:19:42.361335+00	\N
4eaa1212-b51a-466f-be15-755901cae465	19c0116c-3b56-484e-a567-e0289afcf8a0	04292b9a-cb6b-4b8a-a8dd-5249b1aa46f4	\N	2026-03-30 16:34:11+00	t	2026-03-23 16:34:11.572849+00	\N
7d1ac15d-8094-45f1-9727-7b23984b3fe2	19c0116c-3b56-484e-a567-e0289afcf8a0	fb277d5b-fb14-4d76-9fe6-7cea25e7b3f5	\N	2026-03-31 02:47:06+00	t	2026-03-24 02:47:06.592205+00	\N
cc941ea1-2023-4b74-b128-e33613eea330	19c0116c-3b56-484e-a567-e0289afcf8a0	4bbc8a63-ad6c-4235-8b37-358504b0693b	\N	2026-03-30 17:18:44+00	t	2026-03-23 17:18:44.554416+00	\N
eec748b5-c0c2-4c56-b1b0-19b1ee71ddae	19c0116c-3b56-484e-a567-e0289afcf8a0	61b4f221-8a6f-4816-96b8-10eb5c0c6036	\N	2026-03-30 17:19:15+00	t	2026-03-23 17:19:15.411495+00	\N
f4e04ea6-4d2f-452f-8a1e-d0356de47c92	7ee97b58-bed6-44cf-b48e-b16b633994ac	e55743ae-c915-4bdb-927d-1a1bd27d24d9	\N	2026-03-31 04:42:32+00	t	2026-03-24 04:42:32.431604+00	\N
76a247db-b84e-4973-b72c-6cb5b445e368	23eb02ba-fc39-44d3-b2fb-db6f8a756395	d6c9bf5c-e54a-4bcc-8c63-062ecec20a36	\N	2026-03-31 05:56:13+00	t	2026-03-24 05:56:13.061522+00	\N
bb3e4153-9eb3-4b27-b8fa-8f4fee436393	7ee97b58-bed6-44cf-b48e-b16b633994ac	daaa48b4-b9b8-4880-b9cd-212d4a1ef0e7	\N	2026-03-31 05:56:24+00	t	2026-03-24 05:56:24.848951+00	\N
08461f24-620f-4661-87f9-18650f8f37bd	19c0116c-3b56-484e-a567-e0289afcf8a0	d235f863-08bf-41ab-aec8-30021a1a173b	\N	2026-03-31 05:57:36+00	t	2026-03-24 05:57:36.190824+00	\N
0c25664b-4f9f-4263-b18a-8f527f5d69fd	19c0116c-3b56-484e-a567-e0289afcf8a0	be3eb127-44f9-41a8-8092-57c33efe9a12	\N	2026-03-31 04:50:24+00	t	2026-03-24 04:50:24.809761+00	\N
144d4813-5ef1-4a53-a535-9c595944008c	19c0116c-3b56-484e-a567-e0289afcf8a0	d0333683-ea8a-432b-b354-cb5c2644bbee	\N	2026-03-31 05:24:09+00	t	2026-03-24 05:24:10.004948+00	\N
4c529091-0ddc-4afe-8272-0d32b7a2a2eb	19c0116c-3b56-484e-a567-e0289afcf8a0	9aed8235-16c6-42c7-a9fe-f4ca7c79f677	\N	2026-03-31 05:24:12+00	t	2026-03-24 05:24:12.768519+00	\N
daf1448f-fdf1-4135-a3d1-a4ca034df497	4cf3005c-9790-4d53-995c-a3121ce6c945	22744d50-f7bb-4d28-9c52-b427c51d6b58	\N	2026-03-31 05:58:47+00	t	2026-03-24 05:58:47.453048+00	\N
5b185568-579d-4515-96e3-78c9c6a1452b	24f7e4a4-3da2-4e50-9702-73e91ebee9f3	219e140b-18f9-46d1-81d1-4dd197b6fb26	\N	2026-03-31 05:59:59+00	t	2026-03-24 05:59:59.91069+00	\N
edfa0aa6-5fa0-436a-9f12-38a868beb783	d79eb64f-ac88-4e89-b8b5-8e465352c47e	7a599b34-9be7-4573-9ca6-f86aa7aaa551	\N	2026-03-31 06:05:06+00	f	2026-03-24 06:05:06.933842+00	\N
4e36d1f4-a993-423e-b193-7b7f5305db43	d79eb64f-ac88-4e89-b8b5-8e465352c47e	9eefc985-3f7e-4f1d-8765-00d3ff85d1f1	\N	2026-03-31 08:00:38+00	f	2026-03-24 08:00:38.198511+00	\N
33969aba-b3ba-4aba-8507-ef01f6b3afdc	19c0116c-3b56-484e-a567-e0289afcf8a0	72f20629-5e54-43f2-90fe-30f02bf3145b	\N	2026-03-31 08:14:57+00	f	2026-03-24 08:14:57.624731+00	\N
0586704a-bad6-49f5-be0a-97bf0201f92e	19c0116c-3b56-484e-a567-e0289afcf8a0	8ef99357-5df0-46d4-9fac-3778b3ddfa76	\N	2026-03-31 09:05:17+00	f	2026-03-24 09:05:17.678134+00	\N
162c03cc-041d-4c33-91cb-c7ee3cdbbb3e	19c0116c-3b56-484e-a567-e0289afcf8a0	ed691ae8-1e44-4978-9169-108e4356e89c	\N	2026-03-31 09:05:20+00	f	2026-03-24 09:05:20.840465+00	\N
9519dedf-243e-4180-adf9-bb61ae0b1dc9	19c0116c-3b56-484e-a567-e0289afcf8a0	600905ee-c5eb-4932-8ef2-fe409b28f5fa	\N	2026-03-31 10:31:58+00	f	2026-03-24 10:31:58.866052+00	\N
fd543e32-20c3-48a6-9368-07b426dd3e6c	19c0116c-3b56-484e-a567-e0289afcf8a0	5ebf780e-610e-4cd6-ba72-e457e047ca2d	\N	2026-03-31 11:04:45+00	f	2026-03-24 11:04:45.37651+00	\N
\.


--
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.rooms (id, code, name, building, floor, capacity, created_at, updated_at, deleted_at, created_by, updated_by) FROM stdin;
402d2280-93f4-4c8f-89ff-8605db02787e	0001	A002	A	0	50	2026-03-22 09:15:17.344431+00	2026-03-22 09:15:17.344435+00	\N	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
d7e7c387-5acf-4e4d-b06b-a23467983191	0002	A001	A	0	60	2026-03-22 09:16:31.121357+00	2026-03-22 09:16:31.121362+00	\N	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
b25f7d44-885e-4487-859a-496b2bbce5d1	0007	A007	A	0	50	2026-03-22 09:22:58.373495+00	2026-03-22 09:31:47.793747+00	2026-03-22 09:31:47.792838+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
d3da6712-2da0-4262-b4eb-6ba0a26bba3f	0006	A006	A	0	40	2026-03-22 09:22:02.955149+00	2026-03-22 09:32:41.371695+00	2026-03-22 09:32:41.37138+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
d0ab216a-4601-49bc-91c0-bd1af7e990a5	0005	A005	A	0	50	2026-03-22 09:20:42.226244+00	2026-03-22 09:35:40.439823+00	2026-03-22 09:35:40.437605+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
a11e9fce-f114-4f17-8e68-33d435b2ea81	0008	A10q	A	1	50	2026-03-22 09:43:06.828075+00	2026-03-22 09:43:13.680949+00	2026-03-22 09:43:13.678329+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
3a6f8abc-2385-40a4-9e90-df1d99522d11	0010	A006	A	0	60	2026-03-22 09:44:55.202886+00	2026-03-22 09:45:29.05784+00	2026-03-22 09:45:29.057353+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
a433da5c-3718-4682-ad2f-eb552dfb6053	0009	A005	A	0	50	2026-03-22 09:43:26.441643+00	2026-03-22 09:45:34.831555+00	2026-03-22 09:45:34.831227+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
a1a63f32-8d02-45c5-8cd6-9e1e26618148	0011	A006	A	0	60	2026-03-22 09:52:09.869727+00	2026-03-22 09:52:16.384411+00	2026-03-22 09:52:16.383888+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
8c678a5f-f251-46ee-846b-7038d19162cb	0012	A005	A	0	50	2026-03-22 09:53:06.572535+00	2026-03-22 09:53:25.777492+00	2026-03-22 09:53:25.776966+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
77da56aa-7954-4164-9e39-0b5680fbebde	0004	A004	A	0	50	2026-03-22 09:20:15.880183+00	2026-03-22 09:56:38.175194+00	2026-03-22 09:56:38.174509+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
d9226671-7840-47d6-ac0a-0d78c2a1626e	0003	A003	A	0	60	2026-03-22 09:17:25.936267+00	2026-03-22 10:25:19.299634+00	2026-03-22 10:25:19.298274+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
6ae854b0-1c85-4147-b839-ad3a1cf56922	0013	A101	A	1	50	2026-03-23 05:08:04.919091+00	2026-03-23 05:08:04.919101+00	\N	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
518f6289-4017-4730-8dab-53477b1db266	0014	A201	A	2	60	2026-03-23 05:32:35.265739+00	2026-03-23 05:32:50.188752+00	2026-03-23 05:32:50.187748+00	19c0116c-3b56-484e-a567-e0289afcf8a0	\N
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.schedules (id, course_id, day_of_week, time_slot_id, created_at, updated_at, deleted_at, created_by, updated_by) FROM stdin;
faa5316e-d067-4ba0-9c31-e898cff6ea21	5237abb1-d881-4d17-9e09-2b1ec353c6e9	3	21	2026-03-23 13:13:00.268766+00	2026-03-23 13:13:00.268773+00	\N	\N	\N
8174318c-d8fe-4b3a-8244-39df59cc619e	921a2653-b1cb-404c-86aa-37de2a47ab7c	2	28	2026-03-23 13:19:45.237166+00	2026-03-23 13:19:45.237172+00	\N	\N	\N
45d60f62-fa6b-4a3d-affd-1b773bb24450	79f73d90-afbb-4019-9fde-ee383e4fc686	3	25	2026-03-23 13:55:04.454645+00	2026-03-23 13:55:04.454649+00	\N	\N	\N
0f0775c4-ce6d-4e9d-ab2b-a02890fcef46	9472af2f-94b2-47e6-8b22-f60449fc1110	3	28	2026-03-23 13:18:14.437996+00	2026-03-23 13:55:31.028538+00	\N	\N	\N
e41085d6-66e5-4136-a871-294eda74934d	adb5a242-bb03-4597-ba12-976a4b2f4b12	1	30	2026-03-23 14:00:47.259944+00	2026-03-23 14:00:47.259948+00	\N	\N	\N
e1583123-e75b-48ec-a8a5-54fde7b79ab6	3078abf6-278b-4409-b544-94eff0cf27df	2	30	2026-03-23 14:03:18.41701+00	2026-03-23 14:03:18.417014+00	\N	\N	\N
815a8528-9dec-4198-a603-f8640fa330fb	fe970ece-85b4-40dc-8766-fe532be568d6	4	30	2026-03-23 14:06:47.637361+00	2026-03-23 14:06:47.637366+00	\N	\N	\N
e10242d8-e865-4c08-80d2-7c321ee509d8	6721380d-c528-45ba-ae7f-3fea28223c4a	3	29	2026-03-23 14:07:59.883244+00	2026-03-23 14:07:59.883249+00	\N	\N	\N
a6906feb-9af0-4e6d-9e1a-9ee8e5b0eeb6	f1c71f4d-96f6-4217-ae1c-4530a68b8bb3	4	29	2026-03-23 14:10:11.663553+00	2026-03-23 14:10:11.663561+00	\N	\N	\N
20079479-29d8-4a16-93d8-b708da9032c9	fbe53de1-2e6f-4063-b940-dd49126681ba	4	30	2026-03-23 14:14:03.728323+00	2026-03-23 14:14:03.728327+00	\N	\N	\N
2836b9f2-62fa-496a-9d90-9d5d878fe570	83c2ae1b-795d-4a4f-94d9-9a8af7079df1	3	27	2026-03-24 05:47:02.109545+00	2026-03-24 05:47:02.109553+00	\N	\N	\N
b6cca6f6-65c5-460d-b998-7d6e4578a7ec	55a06610-7bfd-4ab3-b277-f6c2ab611754	3	21	2026-03-24 05:47:55.784075+00	2026-03-24 05:47:55.784079+00	\N	\N	\N
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.sessions (id, course_id, schedule_id, status, created_at, start_time, end_time, checkin_window_start, checkin_window_end, updated_at, deleted_at, session_date) FROM stdin;
\.


--
-- Data for Name: student_groups; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.student_groups (id, code, name, advisor_id, created_at, updated_at, deleted_at, created_by, updated_by, department_id) FROM stdin;
268f9b04-b04f-4553-b3d1-99805d106228	0001	48K21.2	4cf3005c-9790-4d53-995c-a3121ce6c945	2026-03-23 04:13:04.780159+00	2026-03-23 04:13:04.780165+00	\N	\N	\N	9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523
ef3ee2ea-aa74-4c4f-aa01-e8a3f478836f	0002	48K14.1	4cf3005c-9790-4d53-995c-a3121ce6c945	2026-03-23 04:13:54.613906+00	2026-03-23 04:13:54.613916+00	\N	\N	\N	9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523
2acafbfa-b49b-4dca-bb88-7bd76e1dc7b0	0003	48K20	90eb4bde-f697-48ca-8e45-627ba953a659	2026-03-23 05:33:19.281114+00	2026-03-23 05:33:19.281122+00	\N	\N	\N	2e727237-931f-411a-ac44-f94b3e653eb5
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.students (id, user_id, pin, created_at, updated_at, student_group_id, deleted_at, student_code, created_by, updated_by) FROM stdin;
1	7ee97b58-bed6-44cf-b48e-b16b633994ac	\N	2026-03-20 17:39:50.884419+00	2026-03-20 17:39:50.884425+00	\N	\N	221121521101	\N	\N
2	d79eb64f-ac88-4e89-b8b5-8e465352c47e	\N	2026-03-21 05:38:22.790328+00	2026-03-21 05:38:22.790335+00	\N	\N	221121513385	\N	\N
4	6b454463-ef8a-4619-98d6-8ec207d543d9	\N	2026-03-21 05:40:18.39304+00	2026-03-21 05:40:18.393044+00	\N	\N	221121513382	\N	\N
5	d26ed111-3809-492b-aede-1937d03080dd	\N	2026-03-21 05:48:45.413522+00	2026-03-21 05:48:45.413527+00	\N	\N	221121521158	\N	\N
6	89cae998-821b-4665-bdd7-39a77763c752	\N	2026-03-21 06:07:46.527433+00	2026-03-21 06:07:46.527442+00	\N	\N	221121521110	\N	\N
7	52ecdf48-6604-4e32-a13c-5b1e2312c8d1	\N	2026-03-21 17:05:38.438792+00	2026-03-21 17:05:38.438796+00	\N	\N	221121521188	\N	\N
8	b90a64ac-289e-4a82-a82a-ec0c1a1cae53	\N	2026-03-23 05:09:36.014502+00	2026-03-23 05:09:36.014508+00	268f9b04-b04f-4553-b3d1-99805d106228	\N	383838838	\N	\N
9	0afb83eb-6159-4d92-ab1b-29383ff0b860	\N	2026-03-23 09:25:03.110759+00	2026-03-23 09:25:03.110767+00	2acafbfa-b49b-4dca-bb88-7bd76e1dc7b0	\N	38383838831	\N	\N
\.


--
-- Data for Name: teachers; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.teachers (id, user_id, teacher_id, phone, created_at, updated_at, deleted_at, department_id) FROM stdin;
1	4cf3005c-9790-4d53-995c-a3121ce6c945	2545884444	\N	2026-03-21 03:57:19.267246+00	2026-03-21 03:57:19.267251+00	\N	a6c2c983-6cd6-4cbb-b402-ba1a18fd1ab2
2	ba09ea0a-9155-4d30-a7f7-f5a7a47bc599	373773373	\N	2026-03-23 04:23:06.157333+00	2026-03-23 04:23:06.157342+00	\N	9dc6f0cb-0c7b-4dda-83e2-a1ac0a50b523
3	90eb4bde-f697-48ca-8e45-627ba953a659	272728282	\N	2026-03-23 04:24:33.660695+00	2026-03-23 04:24:33.660701+00	\N	2e727237-931f-411a-ac44-f94b3e653eb5
4	982e7aab-932a-4a97-b774-6f9fb2780ba0	3484848	\N	2026-03-23 04:31:31.136261+00	2026-03-23 04:31:31.136267+00	\N	8110f384-f41b-4f6e-84cf-1874852a2a19
5	fb0cef2c-c64c-4694-8385-17c049166aea	48383883	\N	2026-03-23 09:26:16.692789+00	2026-03-23 09:26:16.692798+00	\N	c1f3ae5b-1559-4968-abef-a3aef44ef832
\.


--
-- Data for Name: time_slots; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.time_slots (id, period_number, start_time, end_time, created_at) FROM stdin;
21	1	07:00:00+00	07:50:00+00	2026-03-23 12:00:57.413445+00
22	2	07:50:00+00	08:40:00+00	2026-03-23 12:00:57.413445+00
23	3	08:50:00+00	09:40:00+00	2026-03-23 12:00:57.413445+00
24	4	09:45:00+00	10:35:00+00	2026-03-23 12:00:57.413445+00
25	5	10:35:00+00	11:25:00+00	2026-03-23 12:00:57.413445+00
26	6	11:35:00+00	12:25:00+00	2026-03-23 12:00:57.413445+00
27	7	13:30:00+00	14:20:00+00	2026-03-23 12:00:57.413445+00
28	8	14:20:00+00	15:10:00+00	2026-03-23 12:00:57.413445+00
29	9	15:20:00+00	16:10:00+00	2026-03-23 12:00:57.413445+00
30	10	16:15:00+00	17:05:00+00	2026-03-23 12:00:57.413445+00
31	11	17:05:00+00	17:55:00+00	2026-03-23 12:00:57.413445+00
32	12	18:05:00+00	18:55:00+00	2026-03-23 12:00:57.413445+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.users (id, email, password_hash, full_name, role, created_at, avatar_url, deleted_at, updated_at) FROM stdin;
42597432-1bd8-4d5c-8706-7596293c5887	student@test.com	$bcrypt-sha256$v=2,t=2b,r=12$is7LrdEac5BrWegFAW74pe$Mp3fAP.MVvkAjtAHJg4VgBs4xWL2x52	H?c Sinh Test	student	2026-03-19 16:37:44.957177+00	/uploads/avatars/42597432-1bd8-4d5c-8706-7596293c5887.jpg	\N	2026-03-19 16:39:32.549638+00
19c0116c-3b56-484e-a567-e0289afcf8a0	admin@test.com	$bcrypt-sha256$v=2,t=2b,r=12$xEecRzrxfZg7ur2cfqplM.$tPDo7iikl0xOICjIcr2PejxPiOc24RK	Admin Test	admin	2026-03-19 16:28:31.283066+00	/uploads/avatars/19c0116c-3b56-484e-a567-e0289afcf8a0.jpg	\N	2026-03-20 09:44:38.150861+00
23eb02ba-fc39-44d3-b2fb-db6f8a756395	teacher@test.com	$bcrypt-sha256$v=2,t=2b,r=12$yCKSiJO9nMppULkuULP9cu$A7PzCZPmSpnUfBhpj/MX5bDkvK0RJOy	Teacher Test	teacher	2026-03-19 16:38:12.355703+00	/uploads/avatars/23eb02ba-fc39-44d3-b2fb-db6f8a756395.jpg	\N	2026-03-20 09:52:05.020885+00
33527004-6529-4cf8-a889-3326fd774bc6	test999@test.com	$bcrypt-sha256$v=2,t=2b,r=12$cf4cBphOstqxJrwV1.OcrO$FTRBxZvgc6X/ePKgprnzF8e8rum3uES	Test User	student	2026-03-20 12:27:47.227658+00	\N	\N	2026-03-20 12:27:47.227665+00
3e4a9a4f-4f01-4018-9f40-61ec31685b33	student1@test.com	$bcrypt-sha256$v=2,t=2b,r=12$0DS5N3lhc7uTjgoBsklwfe$kIFMQZFlmUeagTcvjhioqqQs4zzTmTe	Trần Minh Đức	student	2026-03-20 12:28:19.865832+00	\N	\N	2026-03-20 12:28:19.86584+00
24f7e4a4-3da2-4e50-9702-73e91ebee9f3	student2@test.com	$bcrypt-sha256$v=2,t=2b,r=12$ZyKjxl0/dFiwxoR9yewcWe$72qnmuFWz7Lo9BDnAOod04rYe1Vm4pK	Trần Minh Đạt	student	2026-03-20 12:32:13.211023+00	\N	\N	2026-03-20 12:32:13.211029+00
327ecef7-06a8-4cb3-a0fd-143a6436ebbe	student3@test.com	$bcrypt-sha256$v=2,t=2b,r=12$CS7OMMkhuB.xO5UWfdAtS.$8QOEElrcbwIMZz5E2muHEyOEVLrspH.	Trần Minh Tuấn	student	2026-03-20 12:32:58.560351+00	\N	\N	2026-03-20 12:32:58.560356+00
fc936617-708b-42f0-b26b-dcba946cd2e3	student4@test.com	$bcrypt-sha256$v=2,t=2b,r=12$blW3jZiM8yLPiMEUdfk1V.$ab6TWaPPuHOxSNAF5dzYzzW/mTyaIgC	Trần Hoàng Anh	student	2026-03-20 17:15:45.363926+00	\N	\N	2026-03-20 17:15:45.363933+00
7ee97b58-bed6-44cf-b48e-b16b633994ac	student5@test.com	$bcrypt-sha256$v=2,t=2b,r=12$zV38ToTmwidNgQz6eZ1tou$9ndbkX54NAjRGoZG5Kdb5RBuTELZen6	Hoàng Phi	student	2026-03-20 17:39:50.872608+00	\N	\N	2026-03-20 17:39:50.872613+00
4cf3005c-9790-4d53-995c-a3121ce6c945	teacher1@test.com	$bcrypt-sha256$v=2,t=2b,r=12$9IbsmH8P20rKr.YL64K7mO$cf.B8Z4Lqcdk19sc32h5MrCBAlUpQNK	Nguyễn Anh Tuấn	teacher	2026-03-21 03:57:19.258191+00	\N	\N	2026-03-21 03:57:19.258196+00
d79eb64f-ac88-4e89-b8b5-8e465352c47e	student6@test.com	$bcrypt-sha256$v=2,t=2b,r=12$/1s8P4EEeiIw2TR4GqJAK.$5Mg/.b/oevceXvxfiXEK8G72vEUd1fe	Lê Anh Khoa	student	2026-03-21 05:38:22.784781+00	\N	\N	2026-03-21 05:38:22.784787+00
6b454463-ef8a-4619-98d6-8ec207d543d9	student8@test.com	$bcrypt-sha256$v=2,t=2b,r=12$erhASGc10LOLSKFZ8wa9O.$iuPv6Z2K37HyOxx7drRs6oQ9q.wwZJS	Lê Anh Kha	student	2026-03-21 05:40:18.391012+00	\N	\N	2026-03-21 05:40:18.391019+00
d26ed111-3809-492b-aede-1937d03080dd	student9@test.com	$bcrypt-sha256$v=2,t=2b,r=12$kvYX77rx31/7u6LXLinWfe$O2lHL2CobHh.l298nbZ0mxziFvXM4E2	Thanh Tú	student	2026-03-21 05:48:45.406382+00	\N	\N	2026-03-21 05:48:45.406389+00
89cae998-821b-4665-bdd7-39a77763c752	student10@test.com	$bcrypt-sha256$v=2,t=2b,r=12$/Htmwq/IuDVo2ZPHG9AZM.$SXJYoFxMVRj89fXiHW7reJ0Qp9SQmgO	Trương Phi	student	2026-03-21 06:07:46.496556+00	\N	\N	2026-03-21 06:07:46.496563+00
52ecdf48-6604-4e32-a13c-5b1e2312c8d1	student11@test.com	$bcrypt-sha256$v=2,t=2b,r=12$yevFaqm2tV.EnW/h3qeKve$Ez/UVCTKfcouQLKOIWL48YMwiaFDLh6	Nguyễn Ga	student	2026-03-21 17:05:38.40715+00	\N	\N	2026-03-21 17:05:38.407159+00
ba09ea0a-9155-4d30-a7f7-f5a7a47bc599	student12@test.com	$bcrypt-sha256$v=2,t=2b,r=12$ugPyp22YgubMlqmmu6K54.$IpSkLlHegT2chvA76qFyYZYVnWhkezq	Lê Anh Quân	teacher	2026-03-23 04:23:06.140949+00	\N	\N	2026-03-23 04:23:06.140959+00
90eb4bde-f697-48ca-8e45-627ba953a659	teacher5@test.com	$bcrypt-sha256$v=2,t=2b,r=12$H65NlacXJ46EZmtdT4Ksoe$m22CXcUa8O.aHq1j8AUejlLBugL044y	Hoàng Văn Huân	teacher	2026-03-23 04:24:33.65541+00	\N	\N	2026-03-23 04:24:33.655418+00
982e7aab-932a-4a97-b774-6f9fb2780ba0	teacher6@test.com	$bcrypt-sha256$v=2,t=2b,r=12$bcWtkCnjZ6MWNNhDZNkkh.$ExNTKDXiAQJdAgJvAhRf8ygQ8CpGWu2	Lê Tú	teacher	2026-03-23 04:31:31.130644+00	\N	\N	2026-03-23 04:31:31.130649+00
b90a64ac-289e-4a82-a82a-ec0c1a1cae53	student13@test.com	$bcrypt-sha256$v=2,t=2b,r=12$kwtATjLq/S.jLHyIpeMy9u$pHuffnJ/GB9//1jdRMF./zt2pvoJEm2	Trần Anh Điền	student	2026-03-23 05:09:35.995533+00	\N	\N	2026-03-23 05:09:35.995538+00
0afb83eb-6159-4d92-ab1b-29383ff0b860	student14@test.com	$bcrypt-sha256$v=2,t=2b,r=12$ZKdu2SpeceULiyFo7NdwNO$iK4Upd8bVyhfkKtq9b8H5f30GmByNkC	Nguyễn Hoàng	student	2026-03-23 09:25:03.097544+00	\N	\N	2026-03-23 09:25:03.09755+00
fb0cef2c-c64c-4694-8385-17c049166aea	teacher7@test.com	$bcrypt-sha256$v=2,t=2b,r=12$h/uw0qv9HcVKfnKLEwGZWu$bnSGhzW/Ebe/ppMexp6V9YX3T.bU4xa	Lê Viết An	teacher	2026-03-23 09:26:16.68603+00	\N	\N	2026-03-23 09:26:16.686037+00
\.


--
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.students_id_seq', 9, true);


--
-- Name: teachers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.teachers_id_seq', 5, true);


--
-- Name: time_slots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.time_slots_id_seq', 32, true);


--
-- Name: student_groups academic_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT academic_classes_pkey PRIMARY KEY (id);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: attendance_audit_logs attendance_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance_audit_logs
    ADD CONSTRAINT attendance_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: attendance_configs attendance_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance_configs
    ADD CONSTRAINT attendance_configs_pkey PRIMARY KEY (id);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: courses classes_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT classes_pkey PRIMARY KEY (id);


--
-- Name: course_enrollments classroom_students_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT classroom_students_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: device_requests device_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.device_requests
    ADD CONSTRAINT device_requests_pkey PRIMARY KEY (id);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: face_embeddings face_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.face_embeddings
    ADD CONSTRAINT face_embeddings_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: students students_student_code_key; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_student_code_key UNIQUE (student_code);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (id);


--
-- Name: teachers teachers_teacher_id_key; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_teacher_id_key UNIQUE (teacher_id);


--
-- Name: time_slots time_slots_period_number_key; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.time_slots
    ADD CONSTRAINT time_slots_period_number_key UNIQUE (period_number);


--
-- Name: time_slots time_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.time_slots
    ADD CONSTRAINT time_slots_pkey PRIMARY KEY (id);


--
-- Name: attendance uq_attendance_session_student; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT uq_attendance_session_student UNIQUE (session_id, student_id);


--
-- Name: course_enrollments uq_enrollment_course_student; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT uq_enrollment_course_student UNIQUE (course_id, student_id);


--
-- Name: schedules uq_schedule_course_day_slot; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT uq_schedule_course_day_slot UNIQUE (course_id, day_of_week, time_slot_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ix_attendance_audit_created; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_audit_created ON public.attendance_audit_logs USING btree (created_at);


--
-- Name: ix_attendance_audit_logs_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_audit_logs_id ON public.attendance_audit_logs USING btree (id);


--
-- Name: ix_attendance_audit_logs_session_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_audit_logs_session_id ON public.attendance_audit_logs USING btree (session_id);


--
-- Name: ix_attendance_audit_logs_student_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_audit_logs_student_id ON public.attendance_audit_logs USING btree (student_id);


--
-- Name: ix_attendance_audit_session; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_audit_session ON public.attendance_audit_logs USING btree (session_id);


--
-- Name: ix_attendance_audit_session_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_audit_session_student ON public.attendance_audit_logs USING btree (session_id, student_id);


--
-- Name: ix_attendance_audit_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_audit_student ON public.attendance_audit_logs USING btree (student_id);


--
-- Name: ix_attendance_checkin_time; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_checkin_time ON public.attendance USING btree (checkin_time);


--
-- Name: ix_attendance_configs_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_configs_id ON public.attendance_configs USING btree (id);


--
-- Name: ix_attendance_configs_session_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_attendance_configs_session_id ON public.attendance_configs USING btree (session_id);


--
-- Name: ix_attendance_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_deleted_at ON public.attendance USING btree (deleted_at);


--
-- Name: ix_attendance_device_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_device_id ON public.attendance USING btree (device_id);


--
-- Name: ix_attendance_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_id ON public.attendance USING btree (id);


--
-- Name: ix_attendance_session_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_session_id ON public.attendance USING btree (session_id);


--
-- Name: ix_attendance_session_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_session_student ON public.attendance USING btree (session_id, student_id);


--
-- Name: ix_attendance_status; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_status ON public.attendance USING btree (status);


--
-- Name: ix_attendance_student_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_student_id ON public.attendance USING btree (student_id);


--
-- Name: ix_course_enrollments_course_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_course_enrollments_course_id ON public.course_enrollments USING btree (course_id);


--
-- Name: ix_course_enrollments_student_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_course_enrollments_student_id ON public.course_enrollments USING btree (student_id);


--
-- Name: ix_courses_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_courses_deleted_at ON public.courses USING btree (deleted_at);


--
-- Name: ix_courses_department_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_courses_department_id ON public.courses USING btree (department_id);


--
-- Name: ix_courses_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_courses_id ON public.courses USING btree (id);


--
-- Name: ix_courses_room_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_courses_room_id ON public.courses USING btree (room_id);


--
-- Name: ix_courses_teacher_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_courses_teacher_id ON public.courses USING btree (teacher_id);


--
-- Name: ix_departments_code; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_departments_code ON public.departments USING btree (code);


--
-- Name: ix_departments_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_departments_deleted_at ON public.departments USING btree (deleted_at);


--
-- Name: ix_departments_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_departments_id ON public.departments USING btree (id);


--
-- Name: ix_departments_name; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_departments_name ON public.departments USING btree (name);


--
-- Name: ix_device_requests_device_code; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_device_requests_device_code ON public.device_requests USING btree (device_code);


--
-- Name: ix_device_requests_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_device_requests_id ON public.device_requests USING btree (id);


--
-- Name: ix_device_requests_room_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_device_requests_room_id ON public.device_requests USING btree (room_id);


--
-- Name: ix_device_requests_status; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_device_requests_status ON public.device_requests USING btree (status);


--
-- Name: ix_devices_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_devices_deleted_at ON public.devices USING btree (deleted_at);


--
-- Name: ix_devices_device_code; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_devices_device_code ON public.devices USING btree (device_code);


--
-- Name: ix_devices_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_devices_id ON public.devices USING btree (id);


--
-- Name: ix_devices_room_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_devices_room_id ON public.devices USING btree (room_id);


--
-- Name: ix_enrollment_course_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_enrollment_course_student ON public.course_enrollments USING btree (course_id, student_id);


--
-- Name: ix_face_embeddings_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_deleted_at ON public.face_embeddings USING btree (deleted_at);


--
-- Name: ix_face_embeddings_device_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_device_id ON public.face_embeddings USING btree (device_id);


--
-- Name: ix_face_embeddings_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_id ON public.face_embeddings USING btree (id);


--
-- Name: ix_face_embeddings_is_active; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_is_active ON public.face_embeddings USING btree (is_active);


--
-- Name: ix_face_embeddings_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_student ON public.face_embeddings USING btree (student_id);


--
-- Name: ix_face_embeddings_student_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_student_id ON public.face_embeddings USING btree (student_id);


--
-- Name: ix_refresh_tokens_token_jti; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_refresh_tokens_token_jti ON public.refresh_tokens USING btree (token_jti);


--
-- Name: ix_refresh_tokens_user_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_refresh_tokens_user_id ON public.refresh_tokens USING btree (user_id);


--
-- Name: ix_rooms_code; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_rooms_code ON public.rooms USING btree (code);


--
-- Name: ix_rooms_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_rooms_deleted_at ON public.rooms USING btree (deleted_at);


--
-- Name: ix_rooms_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_rooms_id ON public.rooms USING btree (id);


--
-- Name: ix_schedules_course_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_schedules_course_id ON public.schedules USING btree (course_id);


--
-- Name: ix_schedules_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_schedules_deleted_at ON public.schedules USING btree (deleted_at);


--
-- Name: ix_sessions_course_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_sessions_course_id ON public.sessions USING btree (course_id);


--
-- Name: ix_sessions_course_start; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_sessions_course_start ON public.sessions USING btree (course_id, start_time);


--
-- Name: ix_sessions_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_sessions_deleted_at ON public.sessions USING btree (deleted_at);


--
-- Name: ix_sessions_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_sessions_id ON public.sessions USING btree (id);


--
-- Name: ix_student_groups_advisor_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_student_groups_advisor_id ON public.student_groups USING btree (advisor_id);


--
-- Name: ix_student_groups_code; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_student_groups_code ON public.student_groups USING btree (code);


--
-- Name: ix_student_groups_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_student_groups_deleted_at ON public.student_groups USING btree (deleted_at);


--
-- Name: ix_student_groups_department_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_student_groups_department_id ON public.student_groups USING btree (department_id);


--
-- Name: ix_student_groups_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_student_groups_id ON public.student_groups USING btree (id);


--
-- Name: ix_students_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_students_deleted_at ON public.students USING btree (deleted_at);


--
-- Name: ix_students_student_group_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_students_student_group_id ON public.students USING btree (student_group_id);


--
-- Name: ix_students_user_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_students_user_id ON public.students USING btree (user_id);


--
-- Name: ix_teachers_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_teachers_deleted_at ON public.teachers USING btree (deleted_at);


--
-- Name: ix_teachers_department_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_teachers_department_id ON public.teachers USING btree (department_id);


--
-- Name: ix_teachers_user_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_teachers_user_id ON public.teachers USING btree (user_id);


--
-- Name: ix_users_deleted_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_users_deleted_at ON public.users USING btree (deleted_at);


--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: vedura
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: ix_users_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_users_id ON public.users USING btree (id);


--
-- Name: student_groups academic_classes_advisor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT academic_classes_advisor_id_fkey FOREIGN KEY (advisor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: attendance_audit_logs attendance_audit_logs_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance_audit_logs
    ADD CONSTRAINT attendance_audit_logs_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE SET NULL;


--
-- Name: attendance_configs attendance_configs_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance_configs
    ADD CONSTRAINT attendance_configs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: attendance attendance_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE SET NULL;


--
-- Name: attendance attendance_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE;


--
-- Name: attendance attendance_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: course_enrollments classroom_students_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT classroom_students_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: course_enrollments course_enrollments_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: courses courses_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: courses courses_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE SET NULL;


--
-- Name: device_requests device_requests_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.device_requests
    ADD CONSTRAINT device_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: device_requests device_requests_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.device_requests
    ADD CONSTRAINT device_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: device_requests device_requests_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.device_requests
    ADD CONSTRAINT device_requests_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE SET NULL;


--
-- Name: devices devices_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE SET NULL;


--
-- Name: face_embeddings face_embeddings_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.face_embeddings
    ADD CONSTRAINT face_embeddings_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE SET NULL;


--
-- Name: face_embeddings face_embeddings_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.face_embeddings
    ADD CONSTRAINT face_embeddings_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: courses fk_courses_teacher_id; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT fk_courses_teacher_id FOREIGN KEY (teacher_id) REFERENCES public.teachers(id) ON DELETE SET NULL;


--
-- Name: teachers fk_teachers_department; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_teachers_department FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: schedules schedules_classroom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_classroom_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: schedules schedules_time_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_time_slot_id_fkey FOREIGN KEY (time_slot_id) REFERENCES public.time_slots(id);


--
-- Name: sessions sessions_classroom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_classroom_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_schedule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES public.schedules(id) ON DELETE SET NULL;


--
-- Name: student_groups student_groups_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT student_groups_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: students students_academic_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_academic_class_id_fkey FOREIGN KEY (student_group_id) REFERENCES public.student_groups(id) ON DELETE SET NULL;


--
-- Name: students students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: teachers teachers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: vedura
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict MwZMFnkigbLGiqEd5AdiRFKecwcjQLBq393iuvPHU8hLWf2kakSWP5e5sGNVygp

