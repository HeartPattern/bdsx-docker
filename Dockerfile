FROM ubuntu as builder

# Install prerequisites
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm git wget

# Download & build bdsx
RUN git clone https://github.com/bdsx/bdsx.git /work
WORKDIR /work
RUN yes y | npm install --unsafe-perm && \
    npm run -s shellprepare || true # shellprepare exit with 1 in normal situation

# Download wine repository key
RUN wget -nc https://dl.winehq.org/wine-builds/winehq.key

FROM ubuntu:impish
EXPOSE 19132/udp

# Install prerequisites
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y gnupg2 software-properties-common

# Add wine repository
COPY --from=builder /work/winehq.key /winehq.key
RUN apt-key add /winehq.key && \
    dpkg --add-architecture i386 && \
    apt-add-repository 'https://dl.winehq.org/wine-builds/ubuntu/ impish main'

# Download & configure wine
RUN apt-get install -y --install-recommends winehq-stable nodejs xvfb
RUN mkdir -p /.wine/prefix
ENV WINEPREFIX=/.wine/prefix
ENV WINEPATH=/.wine
ENV WINEDEBUG=fixme-all
RUN wine winecfg && \
    wine cmd /c && \
    k='HKLM\System\CurrentControlSet\Control\Session Manager\Environment' && \
    pathext_orig=$( wine reg query "$k" /v PATHEXT | tr -d '\r' | awk '/^  /{ print $3 }' ) && \
    echo "$pathext_orig" | grep -qE '(^|;)\.(;|$)' || wine reg add "$k" /v PATHEXT /f /d "${pathext_orig};."

# Copy bdsx
COPY --from=builder /work/bdsx /root/bdsx
COPY --from=builder /work/bedrock_server /root/bedrock_server
COPY --from=builder /work/node_modules /root/node_modules
COPY --from=builder /work/launcher.js /work/package.json /root/
RUN echo "require('fs').existsSync('./plugins') && require('./plugins');" >> /root/index.js

WORKDIR /root/bedrock_server
CMD Xvfb :0 & \
    DISPLAY=:0 \
    WINEDEBUG=fixme-all \
    wine ./bedrock_server.exe ..
