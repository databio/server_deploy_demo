FROM databio/refgenieserver

COPY config/staging_archive.yaml /genome_config.yaml

ENTRYPOINT ["refgenieserver", "serve", "-c", "/genome_config.yaml"]
