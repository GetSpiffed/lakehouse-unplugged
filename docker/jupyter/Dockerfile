ARG BASE_IMAGE=lakehouse-unplugged-spark-base:latest
FROM ${BASE_IMAGE}

# Zorg dat de Spark distro uit spark-base gebruikt wordt
ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${PATH}"

# Install Jupyter + PySpark bindings
RUN pip install --no-cache-dir notebook jupyterlab ipykernel pyspark==3.5.1

# registreer een kernel naam
RUN python -m ipykernel install --name lakehouse --display-name "Lakehouse (Spark Driver)" --sys-prefix

# Jupyter config
RUN mkdir -p /root/.jupyter && \
    echo "c = get_config()" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.open_browser = False" >> /root/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.token = ''" >> /root/.jupyter/jupyter_notebook_config.py

WORKDIR /workspace

EXPOSE 8888
CMD ["bash", "-lc", "echo \"SPARK_HOME=$SPARK_HOME\" && spark-submit --version && jupyter notebook --allow-root"]
