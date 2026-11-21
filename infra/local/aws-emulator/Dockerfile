FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal

ARG TARGETARCH=amd64

RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -fsSL "https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest/aws-emulator-${ARCH}.rpm" -o /tmp/aws-emulator.rpm && \
    rpm -i /tmp/aws-emulator.rpm && \
    rm -f /tmp/aws-emulator.rpm && \
    mkdir -p /home/emulator/.aws/emulator && \
    chown -R 1000:1000 /home/emulator

USER 1000:1000

ENV HOME=/home/emulator \
    EMULATOR_BIND_ADDRESS=0.0.0.0

EXPOSE 9297

ENTRYPOINT ["aws-emulator"]
