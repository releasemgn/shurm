-- disable new connections
alter system enable restricted session;

-- kill all application sessions
set serveroutput on
declare
	l_count integer;
begin
	-- lock all users
	for rec in (
		SELECT 	username 
		FROM 	all_users 
		WHERE 	username IN ( @SCHEMA_LIST@ )
	) loop
		execute immediate 'alter user ' || rec.username || ' account lock';
	end loop;

	-- kill sessions
	for rec in (
		SELECT	s.sid s , s.serial# p , s.username
		FROM 	v$session s
		WHERE	s.username in ( @SCHEMA_LIST@ ) 
	) loop
		-- kill session
		begin
			dbms_output.put_line( 'drop session of ' || rec.username );
			execute immediate 'alter system kill session ''' || rec.s || ',' || rec.p || ''' immediate';
		exception when others then
			l_count := l_count + 1;
		end;
	end loop;

	-- wait for completion
	while 1 = 1 loop
		select count(*) into l_count from v$session s where s.username in ( @SCHEMA_LIST@ );
		dbms_output.put_line( 'active sessions=' || l_count );
		if l_count = 0 then
			exit;
		end if;
	end loop;

end;
/

drop table system.admindb_dropobj;
create table system.admindb_dropobj ( oschema varchar2(128) , otype varchar2(128) , oname varchar2(128) , status char(1) , errm varchar2(250) null );

-- drop user objects
declare
	procedure p_drop_user( p_user varchar2 ) is
		l_emesg varchar2(250);
	begin
		for recobj in ( select object_type , object_name from dba_objects where owner = p_user ) loop
			begin
				if recobj.object_type = 'TABLE' then
					execute immediate 'drop table ' || p_user || '.' || recobj.object_name || ' cascade constraints';
				else
					execute immediate 'drop ' || recobj.object_type || ' ' || p_user || '.' || recobj.object_name;
				end if;
				insert into system.admindb_dropobj ( oschema , otype , oname , status ) values ( p_user , recobj.object_type , recobj.object_name , 'Y' );
			exception when others then
				l_emesg := SQLERRM;
				insert into system.admindb_dropobj ( oschema , otype , oname , status , errm ) values ( p_user , recobj.object_type , recobj.object_name , 'N' , l_emesg );
			end;
			commit;
		end loop;
	end;
begin
	for rec in (
		SELECT 	username 
		FROM 	all_users 
		WHERE 	username IN ( @SCHEMA_LIST@ )
	) loop
		p_drop_user( rec.username );
	end loop;
end;
/

-- save tablespaces
drop table tmp_savetablespaceinfo;
create table tmp_savetablespaceinfo as
SELECT 	u.username as OWNER , d.TABLESPACE_NAME as TABLESPACE_NAME , min( FILE_NAME ) as FILE_NAME
FROM 	sys.all_users u , sys.dba_data_files d
WHERE 	d.TABLESPACE_NAME like u.username || '!_%' escape '!' and u.username in ( @SCHEMA_LIST@ )
GROUP BY u.username , d.TABLESPACE_NAME;

-- drop users
begin
	for rec in (
		SELECT 	username 
		FROM 	all_users 
		WHERE 	username IN ( @SCHEMA_LIST@ )
	) loop
		-- drop user
		dbms_output.put_line( 'drop user of ' || rec.username );
		begin
			execute immediate 'drop user ' || rec.username || ' cascade';
		exception when others then
			dbms_output.put_line( 'exception when dropping user=' || rec.username );
		end;			
	end loop;
end;
/

-- recreate tablespaces
declare
	l_droptbs varchar2(10) := '@DROPTBS@';
begin
	if l_droptbs = 'yes' then
		for rec in ( select * from tmp_savetablespaceinfo ) loop
			dbms_output.put_line( 'drop tablespace ' || rec.TABLESPACE_NAME );
			execute immediate 'DROP TABLESPACE ' || rec.TABLESPACE_NAME || ' INCLUDING CONTENTS AND DATAFILES';
		end loop;

		for rec in ( select * from tmp_savetablespaceinfo ) loop
			execute immediate 'CREATE TABLESPACE ' || rec.TABLESPACE_NAME || ' LOGGING datafile ''' || rec.FILE_NAME || ''' size 100M autoextend ON next 100M extent management local';
		end loop;
	end if;
end;
/

-- restore connections
alter system disable restricted session;
