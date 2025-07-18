/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SHORT_READS_PREPROC              } from '../subworkflows/local/short_reads_preproc'
include { FASTQC                          } from '../modules/nf-core/fastqc/main'
//include { ONT_READS_PREPROC                } from '../subworkflows/local/ont_reads_preproc'
//include { ASSEMBLING_AUTOCYCLER_RAW_GENOME } from '../subworkflows/local/assembling_autocycler_raw_genome'
//include { HYBRID_GENOME_POLISHING          } from '../subworkflows/local/hybrid_genome_polishing'
//include { GENOME_POSTPROCESSING            } from '../subworkflows/local/genome_postprocessing'
include { MULTIQC                          } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                 } from 'plugin/nf-schema'
include { paramsSummaryMultiqc             } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML           } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText           } from '../subworkflows/local/utils_nfcore_assembly_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ASSEMBLY {

    take:
    ch_samplesheet // channel: samplesheet read in from --input


    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // Generating sample data from input samplesheet
    //
    ch_samples = ch_samplesheet.map { row ->
    def meta = [:]
    meta.id = row.id[0]
    meta.fq_short_F = row.fq_short_F[0]
    meta.fq_short_R = row.fq_short_R[0]
    meta.fq_ont = row.fq_ont[0]
    meta.reference_fasta = row.reference_fasta[0]
    meta.reference_gff = row.reference_gff[0]
    meta.genome_size = row.genome_size[0]
    meta.target_coverage_short = row.target_coverage_short[0]
    meta.target_coverage_ont = row.target_coverage_ont[0]
    meta.seed = row.seed[0]
    
    if (meta.fq_short_R) {
        meta.single_end = false
    } else {
        meta.single_end = true
    }
    

    def short_reads = meta.single_end ? 
        [meta.fq_short_F]:
        [meta.fq_short_F, meta.fq_short_R]
    
    def long_reads = meta.fq_ont==null ?
        null:
        [meta.fq_ont]
        
    return [meta, short_reads, long_reads]
    }


    // ch_samples.view()

    // MODULE: Preprocessing: short reads
    SHORT_READS_PREPROC(ch_samples.map { meta, short_reads, _long_reads ->
                                            [meta, short_reads] })

    // MODULE: FastQC
    FASTQC(SHORT_READS_PREPROC.out.preprocessed_short_reads)

    // Collecting tool reports for MultiQC
    ch_multiqc_files = ch_multiqc_files
                            .mix(SHORT_READS_PREPROC.out.fastp_json.map { meta, json ->
                                                        json })
                            .mix(FASTQC.out.zip.map { meta, zip ->
                                                        zip })

    // Filling ch_versions
    ch_versions = ch_versions
                    .mix(SHORT_READS_PREPROC.out.versions)
                    .mix(FASTQC.out.versions)
    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'assembly_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo        = Channel.fromPath(
        "$projectDir/assets/omg_logo_v0.png", checkIfExists: true)
    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    // !!
    // assembly_fasta
    // assembly_fasta_qc_reports
    // assembly_gff
    
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
