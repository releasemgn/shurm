drop table system.admindb_truncateobj;
create table system.admindb_truncateobj ( oschema varchar2(128) , otype varchar2(128) , oname varchar2(128) , status char(1) , errm varchar2(250) null );

-- prepare import data for specific tables

declare
	l_schema_one varchar2(30) := '@SCHEMAONE@';

	procedure p_prepare_table( p_schema varchar2 , p_table varchar2 ) is
		l_emesg varchar2(250);
	begin
		-- ensure no data in the table
		execute immediate 'TRUNCATE TABLE ' || p_schema || '.' || p_table;

		insert into system.admindb_truncateobj ( oschema , oname , status , errm )
		values( p_schema , p_table , 'Y' , NULL );
		commit;
	exception when others then
		l_emesg := SQLERRM;
		insert into system.admindb_truncateobj ( oschema , otype , oname , status , errm )
		values( p_schema , p_table , 'N' , l_emesg );
		commit;
	end;
begin
	if l_schema_one = 'all' then
		for rec in ( select tschema , tname from @C_ENV_CONFIG_TABLESET@ where status = 'S' and
					( tschema , tname ) in ( select owner , table_name from dba_tables ) ) loop
			p_prepare_table( rec.tschema , rec.tname );
		end loop;

		for rec in ( select owner , table_name from dba_tables where 
					owner in ( select tschema from @C_ENV_CONFIG_TABLESET@ where status = 'S' and tname = '*' ) ) loop
			p_prepare_table( rec.owner , rec.table_name );
		end loop;
	else
		for rec in ( select tschema , tname from @C_ENV_CONFIG_TABLESET@ where tschema = l_schema_one and status = 'S' and
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
