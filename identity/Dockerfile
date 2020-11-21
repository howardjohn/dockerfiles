FROM python:alpine

RUN pip3 install -q Flask==0.11.1 requests==2.18.4

ADD ./service.py /

CMD ["python3", "/service.py"]
