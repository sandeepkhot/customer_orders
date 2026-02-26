procedure get_job_data(
    log_lvl in varchar2 default 'ERROR')
is
    l_module            varchar2(128) := 'GET_JOB_DATA';
    l_oci_bucket        varchar2(256) := 'appctrl_export';
    l_metric_namespace  varchar2(32)  := 'adbs_analytics';
    l_metric_key        varchar2(32)  := 'job';
    l_obj_ext           varchar2(32)  := '.json';
    l_filename_delim    varchar2(3)   := '-';
    l_metric_version    pls_integer   := 1.0;
    l_fetch_size        pls_integer   := 20000;
    l_batch_id          varchar2(128) := to_char(sys_guid());
    l_stmt              clob;

    -- Timer variables                                     
    l_epoch_ts          pls_integer;
    l_collection_ts     timestamp;
    l_collection_ts_str varchar2(32);
    l_elapsed_cpu_time  number;
    l_elapsed_time      number;

    -- JSON Variables
    l_log_json          json_object_t;
    l_err_json          json_object_t;

    -- File name variables
    l_obj_blob          blob;
    l_log_blob          blob;
    l_err_blob          blob;
    l_object_uri        varchar2(2000);
    l_obj_file_name     varchar2(256);
    l_log_file_name     varchar2(256);
    l_err_file_name     varchar2(256);
begin
    -- Can't use cloud logger on a standby instance so enable print.
    if log_lvl = 'STDOUT'
    then
        dbms_output.put_line('STATUS: Initiating broker job data extract.');
    end if;

    -- Can't use cloud logger on a standby instance so enable print.
    if log_lvl = 'STDOUT'
    then
        dbms_output.put_line('APPCTRL broker job data URI: '
            || get_object_store_uri() || '/' || l_oci_bucket);
    end if;

    -- Prepare statement to pull tenant db job data
    l_stmt := '
        WITH t as (
            SELECT
                *
            FROM
                centralcdb_admin_job c
            WHERE
                c.CREATED 
            BETWEEN 
                (LOCALTIMESTAMP - INTERVAL ''''1'''' HOUR)
            AND
                (LOCALTIMESTAMP - INTERVAL ''''0'''' HOUR)
            AND
                c.TYPE in (
                    7,
                    8,
                    9,
                    10,
                    11,
                    12,
                    13,
                    17,
                    18,
                    22,
                    23,
                    24,
                    46,
                    47,
                    52,
                    56,
                    72,
                    87,
                    125,
                    151,
                    170,
                    182,
                    183, -- <-- Added for Jira SAM1-12
                    184,
                    545,
                    609
                )
        )    
        SELECT
            JSON_OBJECT(* RETURNING BLOB) as json_row
        FROM
            t 
    ';

    -- Capture collection timestamp before statement execution
    -- in epoch format 
    l_epoch_ts := get_epoch_ts();

    -- Convert epoch timestamp to Oracle timestamp 
    l_collection_ts := to_timestamp('1970-01-01 00:00:00.0',
        'YYYY-MM-DD HH24:MI:SS.FF') 
        + numtodsinterval(l_epoch_ts, 'SECOND');

    l_collection_ts_str := 
        to_char(l_collection_ts, 'YYYY-MM-DD HH24:MI:SS.FF');

    -- Start timer
    l_elapsed_cpu_time := dbms_utility.get_cpu_time();
    l_elapsed_time     := dbms_utility.get_time();

    -- Get query results in JSON format into a BLOB
    DBMS_LOB.createTemporary(lob_loc => l_obj_blob, cache => TRUE);

    l_obj_blob := get_results_json_blob_from_pdb(
        p_stmt => l_stmt,
        p_schema => 'ADMIN',
        p_container => 'PDBCS',
        p_fetch_size => l_fetch_size);

    -- Stop timer
    l_elapsed_cpu_time := dbms_utility.get_cpu_time() - l_elapsed_cpu_time;
    l_elapsed_time     := dbms_utility.get_time() - l_elapsed_time;

    -- Construct file name for the data object
    l_obj_file_name := l_epoch_ts
        || '-'
        || upper(SYS_CONTEXT('USERENV', 'INSTANCE_NAME'))
        || '_'
        || l_metric_key
        || '_data'
        || l_obj_ext;

    -- Construct Object Store URI for data JSON file
    l_object_uri := get_object_store_uri()
        || '/'
        || l_oci_bucket
        || '/'
        || l_obj_file_name;

    -- Upload data BLOB into the Object Store
    execute immediate 'begin '
        || 'dbms_cloud.put_object('
        || 'object_uri => :1, '
        || 'contents   => :2 '
        || '); end;' 
    using
        in l_object_uri,
        in l_obj_blob;


    <<end_execution>>

    -- Can't use cloud logger on a standby instance so enable print.
    if log_lvl = 'STDOUT'
    then
        dbms_output.put_line('Completed successfully.');
    end if;

exception
    --Output when no records are returned
    when no_data_found 
    then
        -- Can't use cloud logger on a standby instance so enable print.
        if log_lvl = 'STDOUT'
        then
            dbms_output.put_line('ERROR: NO_DATA_FOUND in ' 
            || l_module || '.');
        end if;

        raise;

    when others 
    then
        -- Can't use cloud logger on a standby instance so enable print.
        if log_lvl = 'STDOUT'
        then
            dbms_output.put_line('Encountered OTHER ERROR in ' 
                || l_module || ': ' || SQLERRM);
        end if;

        -- Log error
        l_err_json := json_object_t;

        l_err_json.put('data_file_name', l_obj_file_name);
        l_err_json.put('export_batch_id', l_batch_id);
        l_err_json.put('collection_ts', l_collection_ts_str);            
        l_err_json.put('metric_key', l_metric_key);
        l_err_json.put('return_code', ABS(SQLCODE));
        l_err_json.put('return_message', SQLERRM);
        l_err_blob := to_blob(utl_raw.cast_to_raw(l_err_json.stringify));

        -- Construct file name for the error JSON
        l_err_file_name := l_epoch_ts
            || '_'
            || l_metric_key
            || '_error'
            || l_obj_ext;

        -- Construct Object Store URI for export error JSON
        l_object_uri := get_object_store_uri()
            || '/'
            || l_oci_bucket
            || '/'
            || l_obj_file_name;

        -- Upload export log BLOB into the Object Store
        execute immediate 'begin '
            || 'dbms_cloud.put_object('
            || 'object_uri => :1, '
            || 'contents   => :2 '
            || '); end;' 
        using
            in l_object_uri,
            in l_err_blob;

        raise;

end get_job_data;