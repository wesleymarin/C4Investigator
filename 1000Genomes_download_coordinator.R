'
This script downloads 30X WGS data from the 1000Genomes project and converts it into FQ data for input into C4Investigator
C4Investigator must be run as a seperate step after downloading and converting the data.
'
library(funr)
library(argparser)
library(parallel)

p <- arg_parser("Run 1000Genomes Coordinator")

# Add command line arguments
p <- add_argument(p, "--fqDirectory", help="The path to your desired output directory for the 1000Genomes data")
p <- add_argument(p, "--population", help="The 1000Genomes population to download eg. FIN. Leave blank for all.")
p <- add_argument(p, "--threads", help="The number of compute threads you want to utilize", default=4, type='integer')
argv <- parse_args(p)
# RSTUDIO / RSCRIPT Initialization variables ------------------------------------------------
data_outputDir <- argv$fqDirectory#'../tgpData/' # <-- set this to whatever path you would like the data to be output to
threads <- argv$threads                # <-- Set this to the maximum number of threads you want the script to use

## --- ##
'After setting the above two variables, run the full script to download the FQ data'
## --- ##

# ---- DEPENDENCIES ----
' if any dependencies are missing, install with
install.packages("plotly",dependencies = T)
'
DIR<-get_script_path()
source(file.path(DIR,'resources/general_functions.R'))
source(file.path(DIR,'resources/tgp_functions.R'))


# Preparation ------------------------------------------------------------------------------
dir.create(data_outputDir, showWarnings = FALSE)
threads <- min(c(detectCores(),threads))
resourceDir <- file.path(DIR,'resources/1000Genomes_resources/')
awsUrl <- 'http://s3.amazonaws.com/1000genomes'


# Read in the data manifests ---------------------------------------------------------------
tgpManifest <- read.table(file.path(resourceDir,'manifest.tsv'), sep='\t',stringsAsFactors = F, header=T, check.names=F)
urlManifest <- read.table(file.path(resourceDir,'tgp_full_30x.tsv'), sep='\t',stringsAsFactors = F,col.names=c('Sample name','url'), check.names=F)
dataManifest <- merge(tgpManifest, urlManifest, by="Sample name")
rownames(dataManifest) <- dataManifest$`Sample name`


# Download the reference if needed ---------------------------------------------------------
refPath <- retrieve_ref(resourceDir)
bedPath <- file.path(resourceDir,'mhc_regions.bed')


# Download 1000Genomes CRAMs and convert to FQ  --------------------------------------------
pop_vect <- unique(dataManifest$`Population code`)
if( !is.na(argv$population) ){
  if( argv$population %in% pop_vect){
    pop_vect <- argv$population
  }else{
    stop(paste0(argv$population,' not valid population code. See ',file.path(resourceDir,'manifest.tsv')))
  }}

for( pop in pop_vect ){
  popData_dir <- file.path(data_outputDir,pop)
  dir.create(popData_dir,showWarnings = F)
  
  popManifest <- dataManifest[dataManifest$`Population code` == pop,]
  
  popData_cramDir <- file.path(popData_dir,'cram')
  dir.create(popData_cramDir,showWarnings = F)
  popData_fqDir <- file.path(popData_dir,'fq')
  dir.create(popData_fqDir,showWarnings = F)
  
  cat(paste('\n\n--> Starting download of',pop,'C4 aligned reads to',popData_cramDir,'<--'))
  cat(paste('\nThere are',length(popManifest$`Sample name`),'samples being downloaded.'))
  cat(paste('\nAfter download they will be converted to fq format.\n'))
  fq_path_list <- mclapply(popManifest$`Sample name`, function(sampleID){
    cram_path <- retrieve_cram(sampleID, popData_cramDir, refPath, bedPath, resourceDir)
    fq_paths <- cram_to_fq(sampleID, cram_path, popData_fqDir)
    file.remove(paste0(sampleID,'.final.cram.crai'))
    return(fq_paths)
  }, mc.cores=threads, mc.silent=F)
  cat('\n\n-- DONE! --')
}
