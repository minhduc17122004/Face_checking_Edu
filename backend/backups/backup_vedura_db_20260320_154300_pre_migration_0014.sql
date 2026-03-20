--
-- PostgreSQL database dump
--

\restrict 2rXMlHPirVpMNUQoCvHHzpFbfa4fO2jXlpV9UX8fETWYlxXEGmX1qGcX2eX5Jgu

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
    version_num character varying(32) NOT NULL
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
    created_at timestamp with time zone DEFAULT now(),
    sync_time timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    CONSTRAINT ck_attendance_status CHECK (((status)::text = ANY ((ARRAY['present'::character varying, 'late'::character varying, 'absent'::character varying])::text[])))
);


ALTER TABLE public.attendance OWNER TO vedura;

--
-- Name: TABLE attendance; Type: COMMENT; Schema: public; Owner: vedura
--

COMMENT ON TABLE public.attendance IS 'New attendance table - replaces logic from attendance_records';


--
-- Name: attendance_records; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.attendance_records (
    id uuid NOT NULL,
    student_id integer NOT NULL,
    class_id uuid,
    record_type character varying(10) DEFAULT 'checkin'::character varying NOT NULL,
    checkin_time timestamp with time zone,
    sync_time timestamp with time zone DEFAULT now() NOT NULL,
    confidence double precision,
    device_id character varying(255),
    status character varying(20) DEFAULT 'present'::character varying NOT NULL,
    latitude double precision,
    longitude double precision,
    image_url text
);


ALTER TABLE public.attendance_records OWNER TO vedura;

--
-- Name: TABLE attendance_records; Type: COMMENT; Schema: public; Owner: vedura
--

COMMENT ON TABLE public.attendance_records IS 'LEGACY TABLE - Data has been migrated to attendance table. Use attendance instead for new records.';


--
-- Name: course_enrollments; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.course_enrollments (
    id uuid NOT NULL,
    classroom_id uuid NOT NULL,
    student_id integer NOT NULL,
    enrolled_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.course_enrollments OWNER TO vedura;

--
-- Name: courses; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.courses (
    id uuid NOT NULL,
    course_name character varying(255) NOT NULL,
    subject character varying(255),
    instructor_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    course_code character varying(50)
);


ALTER TABLE public.courses OWNER TO vedura;

--
-- Name: devices; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.devices (
    id uuid NOT NULL,
    device_name character varying(255) NOT NULL,
    device_type character varying(50),
    location character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    last_seen timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    course_id uuid,
    last_active_at timestamp with time zone,
    ip_address character varying(45),
    deleted_at timestamp with time zone,
    device_secret character varying(255),
    api_key character varying(64),
    last_token_at timestamp with time zone,
    mac_address character varying(17)
);


ALTER TABLE public.devices OWNER TO vedura;

--
-- Name: face_embeddings; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.face_embeddings (
    id uuid NOT NULL,
    student_id integer NOT NULL,
    embedding_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    device_id uuid,
    is_active boolean NOT NULL,
    quality_score double precision,
    captured_at timestamp with time zone DEFAULT now()
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
    revoked boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    device_info jsonb
);


ALTER TABLE public.refresh_tokens OWNER TO vedura;

--
-- Name: schedules; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.schedules (
    id uuid NOT NULL,
    course_id uuid NOT NULL,
    day_of_week integer NOT NULL,
    time_slot_id integer NOT NULL,
    room character varying(255),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    CONSTRAINT ck_day_of_week CHECK (((day_of_week >= 1) AND (day_of_week <= 7)))
);


ALTER TABLE public.schedules OWNER TO vedura;

--
-- Name: TABLE schedules; Type: COMMENT; Schema: public; Owner: vedura
--

COMMENT ON TABLE public.schedules IS 'Weekly class schedule - links classroom to day and time slot';


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.sessions (
    id uuid NOT NULL,
    course_id uuid NOT NULL,
    schedule_id uuid,
    status character varying(20) DEFAULT 'scheduled'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone,
    checkin_window_start timestamp with time zone,
    checkin_window_end timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    session_date date NOT NULL,
    CONSTRAINT ck_session_status CHECK (((status)::text = ANY ((ARRAY['scheduled'::character varying, 'active'::character varying, 'closed'::character varying])::text[])))
);


ALTER TABLE public.sessions OWNER TO vedura;

--
-- Name: TABLE sessions; Type: COMMENT; Schema: public; Owner: vedura
--

COMMENT ON TABLE public.sessions IS 'Attendance session - actual instance of a scheduled class';


--
-- Name: student_groups; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.student_groups (
    id uuid NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255),
    faculty character varying(255),
    course_year character varying(10),
    advisor_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone
);


ALTER TABLE public.student_groups OWNER TO vedura;

--
-- Name: students; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.students (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    pin character varying(10),
    job_title character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    student_group_id uuid,
    deleted_at timestamp with time zone
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
    employee_code character varying(50),
    phone character varying(20),
    department character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.time_slots OWNER TO vedura;

--
-- Name: TABLE time_slots; Type: COMMENT; Schema: public; Owner: vedura
--

COMMENT ON TABLE public.time_slots IS 'Global period definitions for school timetable';


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
    role character varying(20) DEFAULT 'student'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    avatar_url character varying(500),
    deleted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now()
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
0014_refactor_schema
\.


--
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.attendance (id, session_id, student_id, checkin_time, status, confidence, device_id, created_at, sync_time, deleted_at) FROM stdin;
\.


--
-- Data for Name: attendance_records; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.attendance_records (id, student_id, class_id, record_type, checkin_time, sync_time, confidence, device_id, status, latitude, longitude, image_url) FROM stdin;
\.


--
-- Data for Name: course_enrollments; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.course_enrollments (id, classroom_id, student_id, enrolled_at) FROM stdin;
\.


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.courses (id, course_name, subject, instructor_id, created_at, updated_at, deleted_at, course_code) FROM stdin;
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.devices (id, device_name, device_type, location, is_active, last_seen, created_at, updated_at, course_id, last_active_at, ip_address, deleted_at, device_secret, api_key, last_token_at, mac_address) FROM stdin;
\.


--
-- Data for Name: face_embeddings; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.face_embeddings (id, student_id, embedding_data, created_at, updated_at, device_id, is_active, quality_score, captured_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.refresh_tokens (id, user_id, token_jti, device_id, expires_at, revoked, created_at, device_info) FROM stdin;
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.schedules (id, course_id, day_of_week, time_slot_id, room, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.sessions (id, course_id, schedule_id, status, created_at, start_time, end_time, checkin_window_start, checkin_window_end, updated_at, deleted_at, session_date) FROM stdin;
\.


--
-- Data for Name: student_groups; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.student_groups (id, code, name, faculty, course_year, advisor_id, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.students (id, user_id, pin, job_title, created_at, updated_at, student_group_id, deleted_at) FROM stdin;
\.


--
-- Data for Name: teachers; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.teachers (id, user_id, employee_code, phone, department, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: time_slots; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.time_slots (id, period_number, start_time, end_time, created_at) FROM stdin;
1	1	07:30:00+00	08:15:00+00	2026-03-19 16:13:11.462218+00
2	2	08:20:00+00	09:05:00+00	2026-03-19 16:13:11.462218+00
3	3	09:10:00+00	09:55:00+00	2026-03-19 16:13:11.462218+00
4	4	10:00:00+00	10:45:00+00	2026-03-19 16:13:11.462218+00
5	5	10:50:00+00	11:35:00+00	2026-03-19 16:13:11.462218+00
6	6	13:00:00+00	13:45:00+00	2026-03-19 16:13:11.462218+00
7	7	13:50:00+00	14:35:00+00	2026-03-19 16:13:11.462218+00
8	8	14:40:00+00	15:25:00+00	2026-03-19 16:13:11.462218+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.users (id, email, password_hash, full_name, role, created_at, avatar_url, deleted_at, created_by, updated_by, updated_at) FROM stdin;
19c0116c-3b56-484e-a567-e0289afcf8a0	admin@test.com	$bcrypt-sha256$v=2,t=2b,r=12$xEecRzrxfZg7ur2cfqplM.$tPDo7iikl0xOICjIcr2PejxPiOc24RK	Admin Test	admin	2026-03-19 16:28:31.283066+00	\N	\N	\N	\N	2026-03-19 16:28:31.283072+00
23eb02ba-fc39-44d3-b2fb-db6f8a756395	teacher@test.com	$bcrypt-sha256$v=2,t=2b,r=12$yCKSiJO9nMppULkuULP9cu$A7PzCZPmSpnUfBhpj/MX5bDkvK0RJOy	Teacher Test	teacher	2026-03-19 16:38:12.355703+00	\N	\N	\N	\N	2026-03-19 16:38:12.35571+00
42597432-1bd8-4d5c-8706-7596293c5887	student@test.com	$bcrypt-sha256$v=2,t=2b,r=12$is7LrdEac5BrWegFAW74pe$Mp3fAP.MVvkAjtAHJg4VgBs4xWL2x52	H?c Sinh Test	student	2026-03-19 16:37:44.957177+00	/uploads/avatars/42597432-1bd8-4d5c-8706-7596293c5887.jpg	\N	\N	\N	2026-03-19 16:39:32.549638+00
\.


--
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.students_id_seq', 1, false);


--
-- Name: teachers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.teachers_id_seq', 1, false);


--
-- Name: time_slots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.time_slots_id_seq', 8, true);


--
-- Name: student_groups academic_classes_code_key; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT academic_classes_code_key UNIQUE (code);


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
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: attendance_records attendance_records_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_pkey PRIMARY KEY (id);


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
-- Name: devices devices_api_key_key; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_api_key_key UNIQUE (api_key);


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
-- Name: teachers teachers_employee_code_key; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_employee_code_key UNIQUE (employee_code);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (id);


--
-- Name: teachers teachers_user_id_key; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_user_id_key UNIQUE (user_id);


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
-- Name: course_enrollments uq_classroom_student; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT uq_classroom_student UNIQUE (classroom_id, student_id);


--
-- Name: schedules uq_schedule; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT uq_schedule UNIQUE (course_id, day_of_week, time_slot_id);


--
-- Name: students uq_students_user_id; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT uq_students_user_id UNIQUE (user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_academic_classes_code; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_academic_classes_code ON public.student_groups USING btree (code);


--
-- Name: idx_attendance_session; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_attendance_session ON public.attendance USING btree (session_id);


--
-- Name: idx_attendance_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_attendance_student ON public.attendance USING btree (student_id);


--
-- Name: idx_classroom_students_classroom; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_classroom_students_classroom ON public.course_enrollments USING btree (classroom_id);


--
-- Name: idx_classroom_students_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_classroom_students_student ON public.course_enrollments USING btree (student_id);


--
-- Name: idx_devices_classroom; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_devices_classroom ON public.devices USING btree (course_id);


--
-- Name: idx_face_embeddings_device; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_face_embeddings_device ON public.face_embeddings USING btree (device_id);


--
-- Name: idx_schedules_classroom; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_schedules_classroom ON public.schedules USING btree (course_id);


--
-- Name: idx_schedules_day; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_schedules_day ON public.schedules USING btree (day_of_week);


--
-- Name: idx_sessions_status; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_sessions_status ON public.sessions USING btree (status);


--
-- Name: idx_students_academic_class; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX idx_students_academic_class ON public.students USING btree (student_group_id);


--
-- Name: ix_attendance_checkin_time; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_checkin_time ON public.attendance USING btree (checkin_time);


--
-- Name: ix_attendance_created_at; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_created_at ON public.attendance USING btree (created_at);


--
-- Name: ix_attendance_dedup; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_dedup ON public.attendance_records USING btree (student_id, checkin_time, record_type);


--
-- Name: ix_attendance_records_class_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_records_class_id ON public.attendance_records USING btree (class_id);


--
-- Name: ix_attendance_records_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_records_id ON public.attendance_records USING btree (id);


--
-- Name: ix_attendance_records_student_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_records_student_id ON public.attendance_records USING btree (student_id);


--
-- Name: ix_attendance_session_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_session_student ON public.attendance USING btree (session_id, student_id);


--
-- Name: ix_attendance_status; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_status ON public.attendance USING btree (status);


--
-- Name: ix_classes_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_classes_id ON public.courses USING btree (id);


--
-- Name: ix_classes_teacher_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_classes_teacher_id ON public.courses USING btree (instructor_id);


--
-- Name: ix_devices_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_devices_id ON public.devices USING btree (id);


--
-- Name: ix_face_embeddings_active_student; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_active_student ON public.face_embeddings USING btree (student_id) WHERE (is_active = true);


--
-- Name: ix_face_embeddings_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_id ON public.face_embeddings USING btree (id);


--
-- Name: ix_face_embeddings_student_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_face_embeddings_student_id ON public.face_embeddings USING btree (student_id);


--
-- Name: ix_refresh_tokens_token_jti; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_refresh_tokens_token_jti ON public.refresh_tokens USING btree (token_jti);


--
-- Name: ix_refresh_tokens_user_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_refresh_tokens_user_id ON public.refresh_tokens USING btree (user_id);


--
-- Name: ix_sessions_course_start; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_sessions_course_start ON public.sessions USING btree (course_id, start_time);


--
-- Name: ix_students_user_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_students_user_id ON public.students USING btree (user_id);


--
-- Name: ix_teachers_user_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_teachers_user_id ON public.teachers USING btree (user_id);


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
-- Name: attendance attendance_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE SET NULL;


--
-- Name: attendance_records attendance_records_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.courses(id) ON DELETE SET NULL;


--
-- Name: attendance_records attendance_records_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


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
-- Name: courses classes_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT classes_teacher_id_fkey FOREIGN KEY (instructor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: course_enrollments classroom_students_classroom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT classroom_students_classroom_id_fkey FOREIGN KEY (classroom_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: course_enrollments classroom_students_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT classroom_students_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: devices devices_classroom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_classroom_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE SET NULL;


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
-- Name: students students_academic_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_academic_class_id_fkey FOREIGN KEY (student_group_id) REFERENCES public.student_groups(id) ON DELETE SET NULL;


--
-- Name: students students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


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

\unrestrict 2rXMlHPirVpMNUQoCvHHzpFbfa4fO2jXlpV9UX8fETWYlxXEGmX1qGcX2eX5Jgu

