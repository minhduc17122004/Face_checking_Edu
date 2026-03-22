--
-- PostgreSQL database dump
--

\restrict jvg6eQfleRa4eRxrZkrah5kDiN8ZnfRHERcSwhzyoQSfhXJZdW6qKJtFgbVrPpM

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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sync_time timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_attendance_status CHECK (((status)::text = ANY ((ARRAY['present'::character varying, 'late'::character varying, 'absent'::character varying])::text[])))
);


ALTER TABLE public.attendance OWNER TO vedura;

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
    instructor_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    course_code character varying(50),
    created_by uuid,
    updated_by uuid
);


ALTER TABLE public.courses OWNER TO vedura;

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
    course_id uuid,
    last_active_at timestamp with time zone,
    ip_address character varying(45),
    deleted_at timestamp with time zone,
    mac_address character varying(17),
    device_code character varying(50) NOT NULL,
    room character varying(100),
    created_by uuid,
    updated_by uuid
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
-- Name: schedules; Type: TABLE; Schema: public; Owner: vedura
--

CREATE TABLE public.schedules (
    id uuid NOT NULL,
    course_id uuid NOT NULL,
    day_of_week integer NOT NULL,
    time_slot_id integer NOT NULL,
    room character varying(100),
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
    CONSTRAINT ck_session_status CHECK (((status)::text = ANY ((ARRAY['scheduled'::character varying, 'active'::character varying, 'closed'::character varying])::text[])))
);


ALTER TABLE public.sessions OWNER TO vedura;

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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid
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
    department character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
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
123456789abc
\.


--
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.attendance (id, session_id, student_id, checkin_time, status, confidence, device_id, created_at, sync_time, deleted_at) FROM stdin;
\.


--
-- Data for Name: course_enrollments; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.course_enrollments (id, student_id, enrolled_at, course_id) FROM stdin;
\.


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.courses (id, course_name, subject, instructor_id, created_at, updated_at, deleted_at, course_code, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.devices (id, device_name, device_type, is_active, created_at, updated_at, course_id, last_active_at, ip_address, deleted_at, mac_address, device_code, room, created_by, updated_by) FROM stdin;
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
b206fa37-038f-4b2d-9949-7095404accd3	24f7e4a4-3da2-4e50-9702-73e91ebee9f3	0b407706-27a0-47ef-9946-56d9f94be930	\N	2026-03-27 12:32:13+00	f	2026-03-20 12:32:13.220624+00	\N
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
921ead79-3550-4795-9a11-e48839e2569a	4cf3005c-9790-4d53-995c-a3121ce6c945	972f6f9f-cee3-4d06-8ac9-e6b5f62596ba	\N	2026-03-28 06:26:03+00	f	2026-03-21 06:26:03.106856+00	\N
ae703af1-5c17-4a91-a6f0-7540e1b50150	19c0116c-3b56-484e-a567-e0289afcf8a0	9312d604-9b88-49ab-86b3-53377bebfa2b	\N	2026-03-28 07:14:45+00	f	2026-03-21 07:14:45.161434+00	\N
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.schedules (id, course_id, day_of_week, time_slot_id, room, created_at, updated_at, deleted_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.sessions (id, course_id, schedule_id, status, created_at, start_time, end_time, checkin_window_start, checkin_window_end, updated_at, deleted_at, session_date) FROM stdin;
\.


--
-- Data for Name: student_groups; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.student_groups (id, code, name, faculty, course_year, advisor_id, created_at, updated_at, deleted_at, created_by, updated_by) FROM stdin;
2144c279-e202-432d-91d1-7c6cfd5f46b3	48K29.1	48K29.1	\N	\N	\N	2026-03-21 06:07:46.515919+00	2026-03-21 06:07:46.515927+00	\N	\N	\N
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.students (id, user_id, pin, created_at, updated_at, student_group_id, deleted_at, student_code, created_by, updated_by) FROM stdin;
1	7ee97b58-bed6-44cf-b48e-b16b633994ac	\N	2026-03-20 17:39:50.884419+00	2026-03-20 17:39:50.884425+00	\N	\N	221121521101	\N	\N
2	d79eb64f-ac88-4e89-b8b5-8e465352c47e	\N	2026-03-21 05:38:22.790328+00	2026-03-21 05:38:22.790335+00	\N	\N	221121513385	\N	\N
4	6b454463-ef8a-4619-98d6-8ec207d543d9	\N	2026-03-21 05:40:18.39304+00	2026-03-21 05:40:18.393044+00	\N	\N	221121513382	\N	\N
5	d26ed111-3809-492b-aede-1937d03080dd	\N	2026-03-21 05:48:45.413522+00	2026-03-21 05:48:45.413527+00	\N	\N	221121521158	\N	\N
6	89cae998-821b-4665-bdd7-39a77763c752	\N	2026-03-21 06:07:46.527433+00	2026-03-21 06:07:46.527442+00	2144c279-e202-432d-91d1-7c6cfd5f46b3	\N	221121521110	\N	\N
\.


--
-- Data for Name: teachers; Type: TABLE DATA; Schema: public; Owner: vedura
--

COPY public.teachers (id, user_id, teacher_id, phone, department, created_at, updated_at, deleted_at) FROM stdin;
1	4cf3005c-9790-4d53-995c-a3121ce6c945	2545884444	\N	Cơ sở lập trình	2026-03-21 03:57:19.267246+00	2026-03-21 03:57:19.267251+00	\N
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
\.


--
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.students_id_seq', 6, true);


--
-- Name: teachers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.teachers_id_seq', 1, true);


--
-- Name: time_slots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vedura
--

SELECT pg_catalog.setval('public.time_slots_id_seq', 8, true);


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
-- Name: ix_attendance_checkin_time; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_attendance_checkin_time ON public.attendance USING btree (checkin_time);


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
-- Name: ix_courses_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_courses_id ON public.courses USING btree (id);


--
-- Name: ix_courses_instructor_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_courses_instructor_id ON public.courses USING btree (instructor_id);


--
-- Name: ix_devices_course_id; Type: INDEX; Schema: public; Owner: vedura
--

CREATE INDEX ix_devices_course_id ON public.devices USING btree (course_id);


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
-- Name: courses classes_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vedura
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT classes_teacher_id_fkey FOREIGN KEY (instructor_id) REFERENCES public.users(id) ON DELETE SET NULL;


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

\unrestrict jvg6eQfleRa4eRxrZkrah5kDiN8ZnfRHERcSwhzyoQSfhXJZdW6qKJtFgbVrPpM

