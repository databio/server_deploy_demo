FROM databio/refgenieserver

COPY config/master_archive.yaml /genome_config.yaml

ENTRYPOINT ["refgenieserver", "serve", "-c", "/genome_config.yaml"]
