-- prepare import data for specific tables

drop table system.admindb_finishobj;
create table system.admindb_finishobj ( oschema varchar2(128) , otype varchar2(128) , oname varchar2(128) , status char(1) , errm varchar2(250) null );

drop table system.admindb_finishobj_index;
create table system.admindb_finishobj_index as
select table_owner , index_name from dba_indexes where logging = 'NO';

drop table system.admindb_finishobj_constraint;
create table system.admindb_finishobj_constraint as
select c.owner owner , c.table_name table_name , c.constraint_name constraint_name , c.constraint_type constraint_type
from 	dba_constraints c , dba_tables t
where	c.owner = t.owner and
	c.table_name = t.table_name and
	c.status = 'DISABLED';

declare
	l_schema_one varchar2(30) := '@SCHEMAONE@';

	procedure p_finish_schema( p_schema varchar2 ) is
		l_emesg varchar2(250);
	begin
		-- recreate indexes
		for rec in ( select table_owner , index_name from system.admindb_finishobj_index where table_owner = p_schema ) loop
			begin
				execute immediate 'alter index ' || p_schema || '.' || rec.index_name || ' LOGGING';
				insert into system.admindb_finishobj ( oschema , otype , oname , status ) values ( p_schema , 'INDEX' , rec.index_name , 'Y' );
			exception when others then
				l_emesg := SQLERRM;
				insert into system.admindb_finishobj ( oschema , otype , oname , status , errm ) values ( p_schema , 'INDEX' , rec.index_name , 'N' , l_emesg );
			end;
			commit;
		end loop;

		-- enable constraints
		for rec in ( 	select 	table_name , constraint_name , constraint_type ,
					CASE WHEN constraint_type IN ( 'P' , 'U' ) THEN 1 ELSE 2 END as Z
				from	system.admindb_finishobj_constraint 
				where 	owner = p_schema 
				order by 4 ) loop
			begin
				execute immediate 'alter table ' || p_schema || '.' || rec.table_name || 
					' modify constraint ' || rec.constraint_name || ' enable novalidate';
				insert into system.admindb_finishobj ( oschema , otype , oname , status ) values ( p_schema , 'CONSTRAINT' , rec.table_name || '.' || rec.constraint_name , 'Y' );
			exception when others then
				l_emesg := SQLERRM;
				insert into system.admindb_finishobj ( oschema , otype , oname , status , errm ) values ( p_schema , 'CONSTRAINT' , rec.table_name || '.' || rec.constraint_name , 'N' , l_emesg );
			end;
			commit;
		end loop;

		-- collect statistics
		-- DBMS_UTILITY.ANALYZE_SCHEMA( p_schema , 'COMPUTE' );
	end;

	procedure p_finish_table( p_schema varchar2 , p_table varchar2 ) is
		l_emesg varchar2(250);
	begin
		begin
			execute immediate 'alter table ' || p_schema || '.' || p_table || ' enable all triggers';
			execute immediate 'alter table ' || p_schema || '.' || p_table || ' LOGGING';
			insert into system.admindb_finishobj ( oschema , otype , oname , status ) values ( p_schema , 'TABLE' , p_table , 'Y' );
		exception when others then
			l_emesg := SQLERRM;
			insert into system.admindb_finishobj ( oschema , otype , oname , status , errm ) values ( p_schema , 'TABLE' , p_table , 'N' , l_emesg );
		end;
		commit;
	end;
begin
	if l_schema_one = 'all' then
		-- schemas
		for rec in ( select distinct tschema from @C_ENV_CONFIG_TABLESET@ where status = 'S' ) loop
			p_finish_schema( rec.tschema );
		end loop;

		-- tables
		for rec in ( select tschema , tname from @C_ENV_CONFIG_TABLESET@ where status = 'S' and tname <> '*' and
					( tschema , tname ) in ( select owner , table_name from dba_tables ) ) loop
			p_finish_table( rec.tschema , rec.tname );
		end loop;

		for rec in ( select owner , table_name from dba_tables where 
					owner in ( select tschema from @C_ENV_CONFIG_TABLESET@ where status = 'S' and tname = '*' ) ) loop
			p_finish_table( rec.owner , rec.table_name );
		end loop;
	else
		-- schemas
		for rec in ( select distinct tschema from @C_ENV_CONFIG_TABLESET@ where tschema = l_schema_one and status = 'S' ) loop
			p_finish_schema( rec.tschema );
		end loop;

		-- tables
		for rec in ( select tschema , tname from @C_ENV_CONFIG_TABLESET@ where tschema = l_schema_one and status = 'S' and tname <> '*' and
					( tschema , tname ) in ( select owner , table_name from dba_tables ) ) loop
			p_finish_table( rec.tschema , rec.tname );
		end loop;

		for rec in ( select owner , table_name from dba_tables where owner = l_schema_one and
					owner in ( select tschema from @C_ENV_CONFIG_TABLESET@ where status = 'S' and tname = '*' ) ) loop
			p_finish_table( rec.owner , rec.table_name );
		end loop;
	end if;
end;
/
