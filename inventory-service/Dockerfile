# Dockerfile for inventory-service
# Multi-stage build for efficient and secure Docker images

# Stage 1: Build the application
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
# Download dependencies separately to leverage Docker layer caching
RUN apk add --no-cache maven && \
    mvn dependency:go-offline -B

COPY src ./src
# Build the application
RUN mvn clean package -DskipTests && \
    mkdir -p target/dependency && \
    (cd target/dependency; jar -xf ../inventory-service-*.jar)

# Stage 2: Create a minimal runtime image
FROM eclipse-temurin:17-jre-alpine
LABEL maintainer="DevOps Team <devops@example.com>"
LABEL application="inventory-service"

# Create a non-root user to run the application
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Set security parameters
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport -Djava.security.egd=file:/dev/./urandom -Dspring.profiles.active=docker"

# Copy application code from the builder stage
ARG DEPENDENCY=/app/target/dependency
COPY --from=builder ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=builder ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=builder ${DEPENDENCY}/BOOT-INF/classes /app

# Expose the application port
EXPOSE 8082

# Set the entry point
ENTRYPOINT ["java", "-cp", "/app:/app/lib/*", "com.programmingtechie.inventoryservice.InventoryServiceApplication"]

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
  CMD wget -q -O /dev/null http://localhost:8082/actuator/health || exit 1