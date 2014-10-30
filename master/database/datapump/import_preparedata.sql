drop table system.admindb_prepareobj;
create table system.admindb_prepareobj ( oschema varchar2(128) , otype varchar2(128) , oname varchar2(128) , status char(1) , errm varchar2(250) null );

-- prepare import data for specific tables

declare
	l_schema_one varchar2(30) := '@SCHEMAONE@';

	procedure p_execute_immediate( p_oschema varchar2 , p_otype varchar2 , p_oname varchar2 , p_sql varchar2 ) is
		l_emesg varchar2(250);
	begin
		execute immediate p_sql;

		insert into system.admindb_prepareobj ( oschema , otype , oname , status , errm )
		values( p_oschema , p_otype , p_oname , 'Y' , NULL );
		commit;
	exception when others then
		l_emesg := SQLERRM;
		insert into system.admindb_prepareobj ( oschema , otype , oname , status , errm )
		values( p_oschema , p_otype , p_oname , 'N' , l_emesg );
		commit;
	end;

	procedure p_prepare_table( p_schema varchar2 , p_table varchar2 ) is
	begin
		p_execute_immediate( p_schema , 'nologging' , p_table , 'ALTER TABLE ' || p_schema || '.' || p_table || ' NOLOGGING' );
		p_execute_immediate( p_schema , 'triggers' , p_table , 'ALTER TABLE ' || p_schema || '.' || p_table || ' DISABLE ALL TRIGGERS' );

		-- disable all constraints
		for rec in ( select CONSTRAINT_NAME from dba_constraints WHERE owner = p_schema and table_name = p_table ) loop
  			p_execute_immediate( p_schema , 'constraint ' || rec.CONSTRAINT_NAME , p_table , 'alter table ' || p_schema || '.' || p_table || ' disable constraint "' || rec.CONSTRAINT_NAME || '" cascade' );
		end loop;

		-- disable all indexes
		for rec in ( select index_name from dba_indexes where table_owner = p_schema and table_name = p_table 
				and index_type <> 'LOB' ) loop
			p_execute_immediate( p_schema , 'index ' || rec.index_name , p_table , 'alter index ' || p_schema || '.' || rec.index_name || ' NOLOGGING' );
		end loop;
	end;
begin
	if l_schema_one = 'all' then
		for rec in ( select tschema , tname from @C_ENV_CONFIG_TABLESET@ where status = 'S' and tname <> '*' and
					( tschema , tname ) in ( select owner , table_name from dba_tables ) ) loop
			p_prepare_table( rec.tschema , rec.tname );
		end loop;

		for rec in ( select owner , table_name from dba_tables where 
					owner in ( select tschema from @C_ENV_CONFIG_TABLESET@ where status = 'S' and tname = '*' ) ) loop
			p_prepare_table( rec.owner , rec.table_name );
		end loop;
	else
		for rec in ( select tschema , tname from @C_ENV_CONFIG_TABLESET@ where tschema = l_schema_one and status = 'S' and tname <> '*' and
					( tschema , tname ) in ( select owner , table_name from dba_tables ) ) loop
			p_prepare_table( rec.tschema , rec.tname );
		end loop;

		for rec in ( select owner , table_name from dba_tables where owner = l_schema_one and
					owner in ( select tschema from @C_ENV_CONFIG_TABLESET@ where status = 'S' and tname = '*' ) ) loop
			p_prepare_table( rec.owner , rec.table_name );
		end loop;
	end if;
end;
/
