get_tgp_url <- function(sample, dataManifest, awsUrl){
  return( file.path(awsUrl,dataManifest[sample,'url']) )}

retrieve_ref <- function(resourceDir){
  refPath <- file.path(resourceDir,"GRCh38_full_analysis_set_plus_decoy_hla.fa")
  if( file.exists(refPath) ){
    cat(paste('\n\t',refPath,'already exists, skipping this download..'))
    return(refPath)}
  else{
    cat('\nDownloading ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/GRCh38_reference_genome/GRCh38_full_analysis_set_plus_decoy_hla.fa')
    cat(' to',resourceDir)
    cat('\tThis might take awhile...')
    downloadRef <- system2('wget', c(paste('-O',refPath),'-q', 
                                     "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/GRCh38_reference_genome/GRCh38_full_analysis_set_plus_decoy_hla.fa"))
    check.system2_output(downloadRef, 'reference download failed')
    cat('\n-- DONE! --')
    return(refPath)}}

retrieve_cram <- function(sampleID, output_dir, ref_path, bed_path, resourceDir){
  output_path <- file.path(output_dir,paste0(sampleID,'_C4.cram'))
  
  if( file.exists(output_path) ){
    cat(paste('\n\t',output_path,'already exists, skipping this download..'))
    return(output_path)}
  
  data_url <- get_tgp_url(sampleID, dataManifest, awsUrl)
  cat(paste('\n\t',data_url,'->',output_path))
  downloadCram <- system2('samtools',c('view',
                                       paste('--reference',ref_path),
                                       '-M',
                                       paste('-L',bed_path),
                                       paste('-o',output_path),
                                       data_url))
  check.system2_output(downloadCram, paste(sampleID,'CRAM download failed:',data_url))
  return(output_path)}

cram_to_fq <- function(sampleID, cram_path, output_path){
  
  f1_path <- file.path(output_path,paste0(sampleID,'_C4_1.fq.gz'))
  f2_path <- file.path(output_path,paste0(sampleID,'_C4_2.fq.gz'))
  
  if( file.exists(f1_path) & file.exists(f2_path) ){
    cat(paste('\n\t',f1_path,'already exists, skipping this conversion..'))
    return(list('f1'=f1_path,'f2'=f2_path))}
  
  cram2fq <- system2('samtools',c('collate','-u','-O',
                                  cram_path,
                                  '|',
                                  'samtools','fastq',
                                  paste('-1',f1_path),
                                  paste('-2',f2_path),
                                  paste('-0','/dev/null'),
                                  paste('-s','/dev/null'),
                                  '-n'))
  check.system2_output(cram2fq, paste(sampleID,'CRAM to FQ failed'))
  file.remove(cram_path)

  return(list('f1'=f1_path,'f2'=f2_path))}
