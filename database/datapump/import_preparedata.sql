-- prepare import data for specific tables

declare
	l_schema_one varchar2(30) := '@SCHEMAONE@';

	procedure p_prepare_table( p_schema varchar2 , p_table varchar2 ) is
	begin
		execute immediate 'ALTER TABLE ' || p_schema || '.' || p_table || ' NOLOGGING';
		execute immediate 'ALTER TABLE ' || p_schema || '.' || p_table || ' DISABLE ALL TRIGGERS';

		-- disable all constraints
		for rec in ( select CONSTRAINT_NAME from dba_constraints WHERE owner = p_schema and table_name = p_table ) loop
			begin
	  			execute immediate 'alter table ' || p_schema || '.' || p_table || ' disable constraint ' || rec.CONSTRAINT_NAME || ' cascade';
			exception when others then
				NULL;
			end;
		end loop;

		-- disable all indexes
		for rec in ( select index_name from dba_indexes where table_owner = p_schema and table_name = p_table 
				and index_type <> 'LOB' ) loop
			begin
				execute immediate 'alter index ' || p_schema || '.' || rec.index_name || ' NOLOGGING';
			exception when others then
				NULL;
			end;
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
