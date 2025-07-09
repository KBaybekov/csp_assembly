// !! Доделать: генерация из одного файла fq/bam и другие режимы

// Сабсэмплинг fq/bam файлов

process RASUSA {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container 'biocontainers/rasusa:2.1.0-1'

    input:
    tuple val(meta), path(reads), val(coverage), val(genome_size), val(seed)

    output:
    path "versions.yml", emit: versions
    tuple path("r1_subsampled.fq"), path("r2_subsampled.fq"), emit: subsampled_fqs

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def reads_to_subsample = reads instanceof List ? 
                "${reads[0]} ${reads[1]}" : 
                "${reads}" // если single-end

    """
    rasusa reads \\
    ${reads_to_subsample} \\
    -s ${seed} \\
    -c ${coverage} \\
    -g ${genome_size} \\
    -o r1_out.fq -o r2_out.fq \\
    -v \\
    ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rarusa: \$(rasusa reads --version 2>&1 | sed 's/^.*RASUSA v//; s/ .*\$//')
    END_VERSIONS
    """
}
