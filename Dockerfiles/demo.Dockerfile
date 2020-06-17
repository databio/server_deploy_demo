FROM databio/refgenieserver

COPY genomes/master_archive.yaml /genome_config.yaml

ENTRYPOINT ["refgenieserver", "serve", "-c", "/genome_config.yaml"]
