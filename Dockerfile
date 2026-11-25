FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests -Dspotless.check.skip=true

FROM eclipse-temurin:17-jre
WORKDIR /app
RUN useradd --system --no-create-home paylink
COPY --from=build /app/target/*.jar app.jar
USER paylink
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]