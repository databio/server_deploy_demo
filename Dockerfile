FROM databio/refgenieserver

COPY genomes/rg.yaml /genome_config.yaml

ENTRYPOINT ["refgenieserver", "serve", "-c", "/genome_config.yaml"]
