include { RASUSA as RASUSA_PRE_SUBSAMPLING} from '../../../modules/local/rasusa/main'
include { RASUSA as RASUSA_SUBSAMPLING } from '../../../modules/local/rasusa/main'
include { FASTP } from '../../../modules/nf-core/fastp/main'

workflow SHORT_READS_PREPROC {
    take:
    ch_samples  // channel: [meta, reads]

    main:
    ch_versions = Channel.empty()

    // Разделяем образцы на те, которые нужно сабсэмплировать и те, которые не нужно
    ch_samples.branch { meta, reads ->
                subsample: meta.target_coverage_short && meta.genome_size
                no_subsample: true }
                .set { branched_samples }

    branched_samples.subsample.view()

    // Ввиду того, что fastp уберёт часть ридов, возьмём с 20%-ным запасом, а после приведём к нужному покрытию повторным сабсэмплингом
    RASUSA_PRE_SUBSAMPLING(branched_samples.subsample.map { meta, reads ->
            tuple(   meta,
                     reads,
                     meta.target_coverage_short * 1.2,
                     meta.genome_size,
                     meta.seed 
                    )})

    ch_fqs2trim = branched_samples.no_subsample
                                .mix(RASUSA_PRE_SUBSAMPLING.out.subsampled_fqs)

    //ch_fqs2trim.view()
    

    FASTP(ch_fqs2trim,
          params.fastp_adapter_fasta ? Channel.fromPath(params.fastp_adapter_fasta) : [],
          params.fastp_discard_trimmed_pass,
          params.fastp_save_trimmed_fail,
          params.fastp_save_merged)


    // Разделяем образцы на те, которые нужно сабсэмплировать и те, которые не нужно
    FASTP.out.reads.branch { meta, reads ->
                subsample: meta.target_coverage_short && meta.genome_size
                no_subsample: true }
                   .set { branched_samples_after_fastp }
    
    // Финальный сабсэмплинг
    RASUSA_SUBSAMPLING(branched_samples_after_fastp.subsample.map { meta, reads ->
            tuple(   meta,
                     reads,
                     meta.target_coverage_short,
                     meta.genome_size,
                     meta.seed 
                    )})

    preprocessed_short_reads = branched_samples.no_subsample
                                .mix(RASUSA_SUBSAMPLING.out.subsampled_fqs)

    ch_versions = ch_versions
                    .mix(RASUSA_SUBSAMPLING.out.versions)
                    .mix(FASTP.out.versions)

    emit:
    preprocessed_short_reads                           = preprocessed_short_reads      // Обработанные риды для дальнейшего использования
    fastp_json                                         = FASTP.out.json       // Для MultiQC
    versions                                           = ch_versions    // Версии всех инструментов

}