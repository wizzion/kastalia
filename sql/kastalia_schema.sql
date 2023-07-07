--
-- PostgreSQL database dump
--

-- Dumped from database version 12.15 (Ubuntu 12.15-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.15 (Ubuntu 12.15-0ubuntu0.20.04.1)

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
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: predicate; Type: TYPE; Schema: public; Owner: kastalia
--

CREATE TYPE public.predicate AS ENUM (
    'is_linked',
    'illustrates',
    'is_uttered_as',
    'is_parent',
    'has_property',
    'created_by',
    'display_at',
    'display_priority',
    'display_duration',
    'has_member',
    'is_member',
    'is_public',
    'has_bookmark',
    'registered',
    'follows',
    'contains',
    'is_plural_of',
    'has_quality',
    'has_answer',
    'translates',
    'misunderstands',
    'repeats',
    'induces'
);


ALTER TYPE public.predicate OWNER TO kastalia;

--
-- Name: zeitgeist_method; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.zeitgeist_method AS ENUM (
    'get',
    'post',
    'script',
    'GET',
    'POST',
    'TEST',
    'LEARN',
    'HEAD'
);


ALTER TYPE public.zeitgeist_method OWNER TO postgres;

--
-- Name: build_family(integer); Type: FUNCTION; Schema: public; Owner: kastalia
--

CREATE FUNCTION public.build_family(p_parent integer) RETURNS SETOF jsonb
    LANGUAGE sql
    AS $$
	  select
	    case
	      when count(x) > 0 then jsonb_build_object('knot_id', obj, 'children', jsonb_agg(f.x), 'name',knots.knot_name,'content',knots.knot_content)
	      else jsonb_build_object('predicate', t.predicate, 'parent',sub,'terminal',obj,'name',knots.knot_name,'content',knots.knot_content)
	    end
	  from bounds as t left join knots on t.obj=knots.knot_id left join build_family(t.obj) as f(x) on true
	  where t.predicate='is_parent' and t.sub = p_parent or (p_parent is null and t.sub is null)
	  group by t.obj, t.sub,t.predicate,knots.knot_name,knots.knot_content;
	$$;


ALTER FUNCTION public.build_family(p_parent integer) OWNER TO kastalia;

--
-- Name: change_hstore_key(public.hstore, text, text); Type: FUNCTION; Schema: public; Owner: kastalia
--

CREATE FUNCTION public.change_hstore_key(h public.hstore, from_key text, to_key text) RETURNS public.hstore
    LANGUAGE plpgsql
    AS $$
begin
    if h ? from_key then
        return (h - from_key) || hstore(to_key, h -> from_key);
    end if;
    return h;
end

$$;


ALTER FUNCTION public.change_hstore_key(h public.hstore, from_key text, to_key text) OWNER TO kastalia;

--
-- Name: bound_id_seq; Type: SEQUENCE; Schema: public; Owner: kastalia
--

CREATE SEQUENCE public.bound_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bound_id_seq OWNER TO kastalia;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bounds; Type: TABLE; Schema: public; Owner: kastalia
--

CREATE TABLE public.bounds (
    bound_id integer DEFAULT nextval('public.bound_id_seq'::regclass) NOT NULL,
    sub integer,
    obj integer,
    predicate public.predicate DEFAULT 'is_parent'::public.predicate,
    ord numeric(10,5) DEFAULT 1 NOT NULL,
    bound_created timestamp without time zone DEFAULT now(),
    bound_creator integer
);


ALTER TABLE public.bounds OWNER TO kastalia;

--
-- Name: knots; Type: TABLE; Schema: public; Owner: kastalia
--

CREATE TABLE public.knots (
    knot_id integer NOT NULL,
    knot_name text,
    knot_content text,
    attributes public.hstore DEFAULT ''::public.hstore NOT NULL,
    knot_created timestamp(0) without time zone DEFAULT now(),
    temp text
);


ALTER TABLE public.knots OWNER TO kastalia;

--
-- Name: knots_knot_id_seq; Type: SEQUENCE; Schema: public; Owner: kastalia
--

CREATE SEQUENCE public.knots_knot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.knots_knot_id_seq OWNER TO kastalia;

--
-- Name: knots_knot_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kastalia
--

ALTER SEQUENCE public.knots_knot_id_seq OWNED BY public.knots.knot_id;


--
-- Name: knots_restore; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.knots_restore (
    knot_id integer,
    knot_name text,
    knot_content text,
    attributes public.hstore,
    knot_created timestamp(0) without time zone,
    temp text
);


ALTER TABLE public.knots_restore OWNER TO postgres;

--
-- Name: zeitgeist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zeitgeist (
    action_executed timestamp without time zone DEFAULT now(),
    agent_id integer,
    action character varying(23),
    method public.zeitgeist_method,
    vars public.hstore
);


ALTER TABLE public.zeitgeist OWNER TO postgres;

--
-- Name: knots knot_id; Type: DEFAULT; Schema: public; Owner: kastalia
--

ALTER TABLE ONLY public.knots ALTER COLUMN knot_id SET DEFAULT nextval('public.knots_knot_id_seq'::regclass);


--
-- Name: bounds bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: kastalia
--

ALTER TABLE ONLY public.bounds
    ADD CONSTRAINT bounds_pkey PRIMARY KEY (bound_id);


--
-- Name: bounds bounds_sub_obj_predicate_ord_key; Type: CONSTRAINT; Schema: public; Owner: kastalia
--

ALTER TABLE ONLY public.bounds
    ADD CONSTRAINT bounds_sub_obj_predicate_ord_key UNIQUE (sub, obj, predicate, ord);


--
-- Name: knots knots_pkey; Type: CONSTRAINT; Schema: public; Owner: kastalia
--

ALTER TABLE ONLY public.knots
    ADD CONSTRAINT knots_pkey PRIMARY KEY (knot_id);


--
-- Name: bounds bounds_bound_creator_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kastalia
--

ALTER TABLE ONLY public.bounds
    ADD CONSTRAINT bounds_bound_creator_fkey FOREIGN KEY (bound_creator) REFERENCES public.knots(knot_id);


--
-- Name: bounds bounds_obj_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kastalia
--

ALTER TABLE ONLY public.bounds
    ADD CONSTRAINT bounds_obj_fkey FOREIGN KEY (obj) REFERENCES public.knots(knot_id);


--
-- Name: bounds bounds_sub_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kastalia
--

ALTER TABLE ONLY public.bounds
    ADD CONSTRAINT bounds_sub_fkey FOREIGN KEY (sub) REFERENCES public.knots(knot_id);


--
-- Name: TABLE zeitgeist; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.zeitgeist TO kastalia;


--
-- PostgreSQL database dump complete
--

