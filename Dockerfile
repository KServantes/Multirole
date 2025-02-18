# Install all the runtime dependencies for Multirole.
FROM alpine:edge AS base
RUN apk add --no-cache --repository "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" boost-filesystem ca-certificates libgit2 libssl3 tcmalloc-minimal@testing sqlite-libs xz && \
	rm -rf /var/log/* /tmp/* /var/tmp/*

# Install all the development environment that Multirole needs.
FROM base AS base-dev
RUN apk add --no-cache --repository "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" boost-dev fmt-dev g++ gperftools-dev@testing libgit2-dev meson ninja openssl-dev sqlite-dev xz-dev && \
	rm -rf /var/log/* /tmp/* /var/tmp/*

# Build multirole, stripping debug symbols to their own files.
FROM base-dev AS built
WORKDIR /root/multirole-src
COPY src/ ./src/
COPY meson.build .
COPY meson_options.txt .
ENV BOOST_INCLUDEDIR=/usr/include/boost BOOST_LIBRARYDIR=/usr/lib
RUN meson setup build -Doptimization=3 -Ddebug=true -Db_lto=true -Db_pie=true -Dcpp_link_args="-static-libstdc++" -Duse_tcmalloc=enabled -Dfmt_ho=true && \
	cd "build" && \
	meson compile && \
	objcopy --only-keep-debug "hornet" "hornet.debug" && \
	strip --strip-debug --strip-unneeded "hornet" && \
	objcopy --add-gnu-debuglink="hornet.debug" "hornet" && \
	objcopy --only-keep-debug "multirole" "multirole.debug" && \
	strip --strip-debug --strip-unneeded "multirole" && \
	objcopy --add-gnu-debuglink="multirole.debug" "multirole"

# Setup the final execution environment.
FROM base
WORKDIR /multirole
COPY etc/config.json .
COPY util/area-zero.sh .
COPY --from=built /root/multirole-src/build/hornet .
COPY --from=built /root/multirole-src/build/multirole .
EXPOSE 7922 7911 34343 62672 49382 43632
CMD [ "./area-zero.sh" ]
