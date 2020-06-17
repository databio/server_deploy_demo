FROM databio/refgenieserver

COPY genomes/demo_archive.yaml /genome_config.yaml

ENTRYPOINT ["refgenieserver", "serve", "-c", "/genome_config.yaml"]
