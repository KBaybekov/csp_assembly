include { RASUSA } from '../../../modules/local/rasusa/main'
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
/*
    RASUSA(branched_samples.subsample.map { meta, reads ->
            [   meta,
                reads,
                meta.target_coverage_short,
                meta.genome_size,
                meta.seed
                ]})
*/
    RASUSA(branched_samples.subsample.map { meta, reads ->
            tuple(   meta,
                reads,
                meta.target_coverage_short,
                meta.genome_size,
                meta.seed )})
    ch_versions = ch_versions.mix(RASUSA.out.versions)
    

    ch_fqs2trim = branched_samples.no_subsample
                                    .mix(RASUSA.out.subsampled_fqs
                                                    .map { meta, r1, r2 -> tuple(meta, [r1, r2]) })

}