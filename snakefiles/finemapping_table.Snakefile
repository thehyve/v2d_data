import os

rule download_credible_set_directory:
    ''' Input is a directory of json parts. Need to do some trickery to download from GCS.
    '''
    input:
        GSRemoteProvider().remote(config['credsets'], keep_local=KEEP_LOCAL)
    output:
        temp(directory('tmp/finemapping/{version}/credset')) # ~ 2GB
        # directory('tmp/finemapping/{version}/credset')
    run:
        # Create input name 
        in_path = os.path.dirname(input[0])
        if not in_path.startswith('gs://'):
            in_path = 'gs://' + in_path
        # Make output directory
        os.makedirs(output[0], exist_ok=True)
        # Download using 
        shell(
            'gsutil -m rsync -r {src} {dest}'.format(
                src=in_path,
                dest=output[0]
            )
        )

rule filter_credible_sets:
    ''' Use grep to filter credset jsons, to keep only lines of type gwas
    '''
    input:
        'tmp/finemapping/{version}/credset'
    output:
        'tmp/finemapping/{version}/credset.gwas_only.json.gz' # ~ 200 MB
    shell:
        # Need -h flag to not show filename in grep output
        'zgrep -h gwas {input}/*.json.gz | gzip -c > {output}'

rule convert_finemapping_to_standard:
    ''' Extract required fields from credible set file
    '''
    input:
        rules.filter_credible_sets.output
    output:
        'output/{version}/finemapping.parquet'
    shell:
        'python scripts/format_finemapping_table.py '
        '--inf {input} '
        '--outf {output}'

rule finemap_to_GCS:
    ''' Copy to GCS
    '''
    input:
        rules.convert_finemapping_to_standard.output
    output:
        GSRemoteProvider().remote(
            '{gs_dir}/{{version}}/finemapping.parquet'.format(gs_dir=config['gs_dir'])
            )
    shell:
        'cp {input} {output}'
