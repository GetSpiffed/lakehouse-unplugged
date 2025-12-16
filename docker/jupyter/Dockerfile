ARG BASE_IMAGE=lakehouse-unplugged-spark-base:latest
FROM ${BASE_IMAGE}
# ... verdere configuratie

# # Dependencies
# RUN apt-get update -qq && \
#     apt-get install -y --no-install-recommends \
#         curl \
#         openjdk-21-jre-headless \
#         && rm -rf /var/lib/apt/lists/*

# Install Jupyter
RUN pip install --no-cache-dir notebook pyspark==3.5.1

# # Iceberg runtime
# RUN mkdir -p /opt/spark/jars && \
#     curl -L -o /opt/spark/jars/iceberg-spark-runtime-3.5_2.12-1.6.0.jar \
#         https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.6.0/iceberg-spark-runtime-3.5_2.12-1.6.0.jar

# Jupyter config
RUN mkdir -p /root/.jupyter && \
    echo "c = get_config()" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.open_browser = False" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.token = ''" >> /root/.jupyter/jupyter_notebook_config.py

WORKDIR /workspace

EXPOSE 8888
CMD ["jupyter", "notebook", "--allow-root"]
