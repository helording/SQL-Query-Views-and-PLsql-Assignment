-- COMP3311 20T3 Assignment 2 Harry Lording z5164744


-- Q1: students who've studied many courses

create view StuListEnrol(unswid, name, course) as
	select p.unswid, p.name, ce.course
	from People p
			join Students s on (p.id = s.id)
			join Course_enrolments ce on (s.id = ce.student);

create or replace view Q1(unswid,name) as
	select unswid, name
	from StuListEnrol
	group by unswid, name
	having count(course) > 65;


-- Q2: numbers of students, staff and both

create or replace view BothStuStaf(count) as
	select count(p.id)
	from People p
		join Students s on (p.id = s.id)
		join Staff st on (st.id = p.id);

create or replace view JustStu(count) as
	select count(p.id)
	from People p
		join Students s on (p.id = s.id)
	except 
	select p.id
	from People p 
		join Staff staf on (p.id = staf.id);

create or replace view JustSta(count) as
	select count(p.id)
	from People p 
		join Staff staf on (p.id = staf.id)
	except
	select p.id
	from People p
		join Students s on (p.id = s.id);

create or replace view Q2(nstudents,nstaff,nboth) as
	select JustStu.count, JustSta.count, BothStuStaf.count
	from JustStu, JustSta, BothStuStaf;


-- Q3: prolific Course Convenor(s)

create or replace view StaffInfo(name, course_count) as
	select p.name, count(course)
	from People p
		join Staff s on (p.id = s.id)
		join Course_staff cs on (s.id = cs.staff)
	where role = (select id from staff_roles where name  = 'Course Convenor')
	group by p.name;

create or replace view Q3(name,ncourses) as
	select name, course_count
	from StaffInfo
	where course_count = (select max(course_count) from StaffInfo);


-- Q4: Comp Sci students in 05s2 and 17s1

create or replace function 
	termId(_year courseyeartype, _sess char(2)) returns integer
as $$
declare
	_id integer;
begin
	select id into _id
	from Terms
	where  year = _year and session = _sess;
	if (not found) then
		return 'No such term';
	end if;
	return _id;
end;
$$ language plpgsql; 

create or replace view Q4a(id,name) as
	select peop.unswid, peop.name
	from Programs p 
		join Program_enrolments pe on (pe.program = p.id)
		join People peop on (pe.student = peop.id)
	where pe.term = (select * from termId(2005, 'S2')) 
		and program = (select id from Programs where name = 'Computer Science' and code = '3978');

---------

create or replace view Q4b(id,name) as
	select peop.unswid, peop.name
	from Programs p 
		join Program_enrolments pe on (pe.program = p.id)
		join People peop on (pe.student = peop.id)
	where pe.term = (select * from termId(2017, 'S1')) 
		and program = (select id from Programs where name = 'Computer Science' and code = '3778');


-- Q5: most "committee"d faculty

create or replace view FacNSchools(facultyName, facId, schoolName, schoolId) as
	select o1.name, o1.id, o2.name, o2.id
	from Orgunits o1
		join Orgunits o2 on (facultyof(o2.id) = o1.id)
	where o1.utype = 1 and o2.utype = 2  
	order by o1.name;

create or replace view SchoolCommittees(facid, comid) as
	select distinct fns.facId, o.id
	from FacNSchools fns
		left outer join  Orgunits o on (fns.schoolId = facultyof(o.id) and o.utype = 9);
	
create or replace view FacultyCommittees(facid, comid) as
	select distinct fns.facId, o.id
	from FacNSchools fns
		left outer join  Orgunits o on (fns.facId = facultyof(o.id) and o.utype = 9);
		
create or replace view TotFacComms(id, count) as
	select facid, count(comid)
	from FacultyCommittees
	group by facid;
	
create or replace view TotSchoComms(id, count) as
	select facid, count(comid)
	from SchoolCommittees
	group by facid;
	
create or replace view FacSchoComms(id, count) as
	select fc.id, fc.count + sc.count
	from TotFacComms fc
		join TotSchoComms sc on (fc.id = sc.id);
	
create or replace function 
	facName(_id integer) returns text
as $$
declare
	_name text;
begin
	select name into _name
	from Orgunits
	where id = _id;
	if (not found) then
		return 'No such unit';
	end if;
	return _name;
end;
$$ language plpgsql;

create or replace view Q5(name) as
	select facName(id)
	from FacSchoComms 
	where count = (select max(count) from FacSchoComms);



-- Q6: nameOf function

create or replace function
   Q6(id integer) returns text
as $$
	select name
	from people 
	where people.id = $1 or people.unswid = $1;	
$$ language sql;


-- Q7: offerings of a subject

create or replace function 
	termName(_id integer) returns text
as $$
declare
	_year integer;
	_sess char(2);
begin
	select year, session into _year, _sess
	from Terms
	where id = _id;
	if (not found) then
		return 'No such term';
	end if;
	
	if (select strpos(_sess, 'T') <> 0 ) then
		return substr(_year::text,3,2)||upper(_sess);
	else 
		return substr(_year::text,3,2)||lower(_sess);
	end if;
end;
$$ language plpgsql;

create or replace function 
	staffName(_id integer) returns text
as $$
declare
	_name text;
begin
	select name into _name
	from People
	where id = _id;
	if (not found) then
		return 'No such staff';
	end if;
	return _name;
end;
$$ language plpgsql;

create or replace function
   Q7(subject text)
     returns table (subject text, term text, convenor text)
as $$
	select cast(sub.code as text), termName(cou.term), staffName(cs.staff)
	from Subjects sub 
		join Courses cou on (sub.id = cou.subject)
		join Course_staff cs on (cou.id = cs.course)
	where role = (select id from staff_roles where name  = 'Course Convenor') 
			and sub.code = $1;
$$ language sql;


-- Q8: transcript

create or replace function 
	programCode(_id integer) returns text
as $$
declare
	_code text;
begin
	select code into _code
	from Programs
	where id = _id;
	if (not found) then
		return 'No such program';
	end if;
	return _code;
end;
$$ language plpgsql;

create or replace function
   Q8(zid integer) returns setof TranscriptRecord
as $$
	declare x RECORD;
	declare _count integer := 0;
	declare transcript TranscriptRecord;
	declare UOCpassed integer := 0;
	declare totalUOCattempted integer := 0;
	declare weightedSumOfMarks integer := 0;
	declare wamValue decimal(4,2);
begin

	for x in
		select subs.code as code, termName(c.term) as term, programCode(pe.program) as prog, substring(subs.name,1,20) as name, ce.mark as mark, ce.grade as grade, subs.uoc as uoc
		from Students s
			join People p on (s.id = p.id)
			join Course_enrolments ce on (s.id = ce.student)
			join Courses c on (c.id = ce.course)
			join Subjects subs on (subs.id =  c.subject)
			join Program_enrolments pe on (s.id = pe.student and pe.term = c.term)
		where p.unswid = zid
		order by c.term, subs.code
	loop
	
		if (x.mark is not null) then 
			totalUOCattempted := totalUOCattempted + x.uoc;
			weightedSumOfMarks := weightedSumOfMarks + (x.uoc * x.mark);
		end if;
		
		if (x.grade not in ('SY', 'PT', 'PC', 'PS', 'CR', 'DN', 'HD', 'A', 'B', 'C', 'XE', 'T', 'PE', 'RC', 'RS') or x.grade is null) then
			transcript.code := x.code;
			transcript.term := x.term;
			transcript.prog := x.prog;
			transcript.name := x.name;
			transcript.mark := x.mark;
			transcript.grade := x.grade;
			transcript.uoc := null;
		else
			transcript.code := x.code;
			transcript.term := x.term;
			transcript.prog := x.prog;
			transcript.name := x.name;
			transcript.mark := x.mark;
			transcript.grade := x.grade;
			transcript.uoc := x.uoc;
			UOCpassed := UOCpassed + x.uoc;
		end if;
		
		_count := _count + 1;
		return next transcript;
		
	end loop;
	
	if (_count = 0) then
		transcript := (null, null, null, 'No WAM available', null, null, null);
		return next transcript;
	elsif (_count > 0) then
		wamValue := cast(weightedSumOfMarks as decimal) / cast(totalUOCattempted as decimal);
		transcript := (null, null, null, 'Overall WAM/UOC', wamValue, null, UOCpassed);
		return next transcript;
	end if;
	
end;
$$ language plpgsql;


-- Q9: members of academic object group

-- Get all the rows of parent and children from aog table
create or replace function 
	aogPnC(gid integer) returns setof acad_object_groups
as $$
	declare x acad_object_groups;
begin

	for x in
		select *
		from acad_object_groups aog
		where aog.id = gid or aog.parent = gid
	loop
		return next x;
	end loop;
	
end;
$$ language plpgsql;

-- Get all codes where gdefby enumerated
create or replace function 
	getEnumCode(aog acad_object_groups) returns setof text
as $$
	declare objId integer;
	declare code text;
begin
	
	for objId in
		execute 'select '|| aog.gtype ||' 
		from '|| cast(aog.gtype as text) ||'_group_members g
		where g.ao_group = '||cast(aog.id as text)
	loop
		execute 'select code
		from '|| cast(aog.gtype as text) ||'s x
		where x.id = '|| cast(objId as text)
		into code;
		return next code;
	end loop;
	
end;
$$ language plpgsql;

-- Get codes when gtype is program and gdefby is pattern
create or replace function 
	getProgPattCode(aog acad_object_groups) returns setof text
as $$
	declare codes textstring;
	declare code text;
begin
	
	select aog.definition into codes;
	for code in
		select * from regexp_matches(codes, '[0-9]{4}', 'g')
	loop
		return next substring(code,2,4);
	end loop;
	
end;
$$ language plpgsql;

-- Get codes when gtype is subject and gdefby is pattern
create or replace function 
	getSubjectCodes(aog acad_object_groups) returns setof text
as $$
	declare codes textstring;
	declare code text;
	declare subcode text;

begin
	
	select aog.definition into codes;
	for code in
		select * from regexp_split_to_table(codes, ',')
	loop
		if (select strpos(cast(code as text), cast('#' as text)) <> 0 ) then
			-- replace # with .
			select regexp_replace(code, '#', '.', 'g') into code;
			--execute search
			for subcode in
				execute 'select code
				from Subjects s
				where s.code ~  '''||code||''''
			loop
				return next subcode;
			end loop;
			
		elsif (select strpos(cast(code as text), cast('[' as text)) <> 0) then
			
			select regexp_replace(code, '#', '.', 'g') into code;

			for subcode in
				execute 'select code
				from Subjects s
				where s.code ~  '''||code||''''
			loop
				return next subcode;
			end loop;
		else
			for subcode in
				select * from regexp_matches(code, '[A-Z]{4}[0-9]{4}', 'g')
			loop
				return next substring(subcode,2,8);
			end loop;
		end if;
		
	end loop;
	
end;
$$ language plpgsql;


create or replace function
   Q9(gid integer) returns setof AcObjRecord
as $$
	declare aObRow acad_object_groups%rowtype;
	declare aor AcObjRecord;
	declare numrow integer;
	declare code text;
begin

	for aObRow in 
		select * from aogPnC(gid)
	loop
		if (aObRow.gdefby like 'enumerated') then
			for code in 
				select * from getEnumCode(aObRow)
			loop 
				aor.objtype := aObRow.gtype;
				aor.objcode := code;
				return next aor;
			end loop;
		elsif (aObRow.gdefby like 'pattern') then
			if (aObRow.gtype like 'program') then
				for code in 
					select * from getProgPattCode(aObRow)
				loop 
					aor.objtype := aObRow.gtype;
					aor.objcode := code;
					return next aor;
				end loop;
			elsif (aObRow.gtype like 'subject') then
				for code in 
					select * from getSubjectCodes(aObRow)
				loop 
					aor.objtype := aObRow.gtype;
					aor.objcode := code;
					return next aor;
				end loop;
			end if;
		end if;
	end loop;
	
end;
$$ language plpgsql;


-- Q10: follow-on courses

create or replace function
   Q10(code text) returns setof text
as $$
	declare inputCode text := code;
	declare _code text;
begin
	
	for _code in
		select distinct s.code
		from Subject_prereqs spr
			join Subjects s on (spr.subject = s.id)
			join Rules r on (r.id = spr.rule)
			join Acad_object_groups aog on (aog.id = r.ao_group)
		where r.type = 'RQ' and aog.definition ~ inputCode
		order by s.code
	loop
		return next _code;
	end loop;
	
end;
$$ language plpgsql;
