#!/bin/bash

if [ "$AWS_ACCESS_KEY_ID" = "" ]; then
    export AWS_ACCESS_KEY_ID=test
fi
if [ "$AWS_SECRET_ACCESS_KEY" = "" ]; then
    export AWS_SECRET_ACCESS_KEY=test
fi
if [ "$AWS_LAMBDA_RUNTIME_API" != "" ]; then
    echo "INIT: Using Lambda API Runtime target host: '$AWS_LAMBDA_RUNTIME_API'"
fi

LAMBDA_USER=sbx_user1051

LOG_FILE=/tmp/__daemons.out
echo -n > $LOG_FILE

# create symlinks for layers
if [ -e /var/task/__layers__ ]; then
    rm -rf /opt
    ln -s /var/task/__layers__ /opt
fi

# fix permissions on /dev/stdin to avoid issues
chown -L $LAMBDA_USER /dev/std* 2> /dev/null

# required to enable tracing using aws-xray-sdk-python
TRACE_ID=$RANDOM$RANDOM$RANDOM
export _X_AMZN_TRACE_ID="Root=$TRACE_ID;Sampled=1;$_X_AMZN_TRACE_ID"
export AWS_XRAY_DAEMON_ADDRESS=127.0.0.1:2000
export _AWS_XRAY_DAEMON_ADDRESS=127.0.0.1
export _AWS_XRAY_DAEMON_PORT=2000
LAMBDA_XRAY_INIT=0

# required to set correct paths for libs included in layers,
# see https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html
LAYER_BASE=/opt
export PYTHONPATH="$PYTHONPATH:$LAYER_BASE:$LAYER_BASE/python:$LAYER_BASE/python/lib/python3.9/site-packages"
export PYTHONPATH="$PYTHONPATH:$LAYER_BASE/python/lib/python3.8/site-packages"
export PYTHONPATH="$PYTHONPATH:$LAYER_BASE/python/lib/python3.7/site-packages"
export PYTHONPATH="$PYTHONPATH:$LAYER_BASE/python/lib/python3.6/site-packages"
export PYTHONPATH="$PYTHONPATH:$LAYER_BASE/python/lib/python2.7/site-packages"
export PYTHONPATH="$PYTHONPATH:/var/runtime"
export NODE_PATH="$NODE_PATH:$LAYER_BASE/nodejs/node_modules:$LAYER_BASE/nodejs/node8/node_modules"
export NODE_PATH="$NODE_PATH:$LAYER_BASE/nodejs/node10/node_modules:$LAYER_BASE/nodejs/node12/node_modules"
export NODE_PATH="$NODE_PATH:$LAYER_BASE/nodejs/node14/node_modules"
export NODE_PATH="$NODE_PATH:/var/runtime/node_modules:/var/task:/var/task/node_modules"
export CLASSPATH="$CLASSPATH:$LAYER_BASE/java:$LAYER_BASE/java/lib"
export PATH="$PATH:$LAYER_BASE/bin:$LAYER_BASE"
export RUBYLIB="$RUBYLIB:$LAYER_BASE/ruby/lib"
export GEM_PATH="$GEM_PATH:$LAYER_BASE/ruby/gems/2.5.0"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$LAYER_BASE/lib"
# TODO: are the LD_LIBRARY_PATH lines below required?
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$LAYER_BASE/python/lib/python3.9/site-packages"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$LAYER_BASE/python/lib/python3.8/site-packages"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$LAYER_BASE/python/lib/python3.7/site-packages"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$LAYER_BASE/python/lib/python3.6/site-packages"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$LAYER_BASE/python/lib/python2.7/site-packages"
# TODO: expand LD_LIBRARY_PATH to include Node.js folders, etc.?

DAEMON_SCRIPT=/tmp/lambda_daemon.py
cat >$DAEMON_SCRIPT <<EOL
_E='LOCALSTACK_HOSTNAME'
_D='strict'
_C='0.0.0.0'
_B='utf-8'
_A=True
import json,os,select,socket,struct,sys,threading,traceback
from multiprocessing import Process
try:from urllib2 import urlopen
except Exception:from urllib.request import urlopen
XRAY_DAEMON_PORT=2000
XRAY_TARGET_URL='http://169.254.170.2:4566/xray_records'
DNS_PORT=53
PROCESS_LOG_FILE='/tmp/__daemons.out'
USE_THREADING=_A
ENV_LAMBDA_RUNTIME='_LAMBDA_RUNTIME'
INTERNAL_LOG_PREFIX='ls-daemon: '
LOCALSTACK_HOSTNAME_IP=None
class FuncThread(threading.Thread):
	def __init__(A,func,**B):threading.Thread.__init__(A);A.daemon=_A;A.func=func;A.params=B
	def run(A):
		try:
			if not USE_THREADING:sys.stdout=sys.stderr=sys.__stdout__=sys.__stderr__=open(PROCESS_LOG_FILE,'a')
			A.func(**A.params)
		except Exception:log('Thread run method %s(%s) failed: %s'%(A.func,A.params,traceback.format_exc()))
	def start(A):
		if USE_THREADING:return super(FuncThread,A).start()
		A.process=Process(target=A.run);A.process.start();return A.process
	def join(A):
		if USE_THREADING:return super(FuncThread,A).join()
		return A.process.join()
def log(msg,log_file=None):
	A=log_file;sys.stdout.flush();A=A or PROCESS_LOG_FILE
	with open(A,'a')as B:B.write('%s\n'%msg)
def send_http(message,target_url):urlopen(target_url,message)
def to_str(obj,encoding=_B,errors=_D):A=obj;return A.decode(encoding,errors)if isinstance(A,bytes)else A
def to_bytes(obj,encoding=_B,errors=_D):
	A=obj
	try:return A.encode(encoding,errors)if isinstance(A,str)else A
	except Exception:return A
def run_xray_loop(*F,**G):
	B=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);B.bind((_C,XRAY_DAEMON_PORT));A=[]
	while _A:
		D,H=B.recvfrom(1024);A.append(to_str(D))
		try:C=''.join(A);assert[json.loads(A)for A in C.split('\n')];A=[]
		except Exception:continue
		try:
			if':0/'in XRAY_TARGET_URL:continue
			send_http(to_bytes(C),XRAY_TARGET_URL)
		except Exception as E:log('ERROR: Unable to send XRay traces to %s: %s'%(XRAY_TARGET_URL,E))
def dns_name_from_wire(message,current):
	C=message;B=current
	if not isinstance(C,(bytes,str)):raise ValueError('Input to dns_name_from_wire(...) must be a byte string')
	G=[];H=B;E=0;A=C[B];A=A if isinstance(A,int)else ord(A);B+=1;F=1
	while A!=0:
		if A<64:
			G.append(C[B:B+A]);B+=A
			if E==0:F+=A
		elif A>=192:
			D=C[B];D=D if isinstance(D,int)else ord(D);B=(A&63)*256+D
			if E==0:F+=1
			if B>=H:raise Exception('BadPointer')
			H=B;E+=1
		else:raise Exception('BadLabelType')
		A=C[B];A=A if isinstance(A,int)else ord(A);B+=1
		if E==0:F+=1
	G.append('');I=[G,F];return I
def update_dns_response(response,old_address,new_address):
	A=response;F=12;G=struct.unpack('!HHHHHH',A[:F]);H=G[2];I=G[3];B=F
	if H==1 and I==1:
		J=dns_name_from_wire(A,B)[1];B+=J+4;K=dns_name_from_wire(A,B)[1];B+=K;struct.unpack('!HHIH',A[B:B+10]);D=B+10;L=socket.inet_ntoa(A[D:D+4])
		if L==old_address:
			E=socket.inet_aton(new_address)
			for C in range(4):M=bytes([E[C]])if isinstance(E[C],int)else E[C];A=set_value_in_str(A,D+C,M)
	return A
def set_value_in_str(string,idx,val):
	B=string;A=val
	try:A=A.encode(_B)if isinstance(A,str)else A
	except UnicodeDecodeError:pass
	return B[:idx]+A+B[idx+1:]
def forward_dns_request_via_tcp(message):
	B=message;D=os.environ[_E];A=socket.socket(socket.AF_INET,socket.SOCK_STREAM,0);A.settimeout(1)
	try:A.connect((D,DNS_PORT));B=struct.pack('!H',len(B))+B;A.sendall(B);F=A.recv(2);G=struct.unpack('!H',F);C=A.recv(G[0]);H=resolve_target_ip();C=update_dns_response(C,'127.0.0.1',H);return C
	except Exception as E:log('Unable to get response from DNS server at %s:%s: %s %s %s'%(D,DNS_PORT,type(E),E,traceback.format_exc()))
	finally:A.close()
def resolve_target_ip():
	global LOCALSTACK_HOSTNAME_IP;A=os.environ[_E]
	if not LOCALSTACK_HOSTNAME_IP:
		LOCALSTACK_HOSTNAME_IP=A
		if not is_ip_address(LOCALSTACK_HOSTNAME_IP):LOCALSTACK_HOSTNAME_IP=socket.gethostbyname_ex(LOCALSTACK_HOSTNAME_IP)[2][0]
		LOCALSTACK_HOSTNAME_IP=str(LOCALSTACK_HOSTNAME_IP)
	return LOCALSTACK_HOSTNAME_IP
def is_ip_address(addr):
	try:socket.inet_aton(addr);return _A
	except socket.error:return False
def run_dns_loop(*F,**G):
	try:B=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);B.bind((_C,DNS_PORT))
	except Exception as A:log('Unable to start DNS server on port %s: %s'%(DNS_PORT,A));return
	while _A:
		D,E=B.recvfrom(2028)
		try:
			C=forward_dns_request_via_tcp(D)
			if C:B.sendto(C,E)
		except Exception as A:log('Error handling DNS request: %s %s'%(type(A),A))
def runtime_request_forwarder(*I,**J):
	B=os.environ.get('AWS_LAMBDA_RUNTIME_API')
	if not B:return
	G=[b'127.0.0.1',b'0.0.0.0',b'localhost'];D=9001;log('%sStarting Runtime API forwarding proxy: localhost:%s -> %s'%(INTERNAL_LOG_PREFIX,D,B));A=B.split(':');H=A[0],int(A[1])if len(A)>1 else 80;C=socket.socket(socket.AF_INET,socket.SOCK_STREAM);C.bind((_C,D));C.listen(1)
	def E(s_src):
		E=s_src;C=socket.socket(socket.AF_INET,socket.SOCK_STREAM);C.connect(H);I=[E,C]
		while _A:
			J,K,K=select.select(I,[],[])
			for F in J:
				A=F.recv(1024)
				if A in[b'','',None]:return
				if F==E:
					for L in G:A=A.replace(b'\r\nHost: %s:%s'%(L,to_bytes(str(D))),b'\r\nHost: %s'%to_bytes(B))
					C.sendall(A)
				elif F==C:E.sendall(A)
	while _A:F,K=C.accept();start_daemon(lambda *A:E(F))
def start_xray_daemon():return start_daemon(run_xray_loop)
def start_dns_daemon():return start_daemon(run_dns_loop)
def start_runtime_forwarder():
	if os.environ.get(ENV_LAMBDA_RUNTIME,'').startswith('provided'):return start_daemon(runtime_request_forwarder)
def start_daemon(func):A=FuncThread(func);A.start();return A
def main():
	try:start_runtime_forwarder();start_xray_daemon();start_dns_daemon().join()
	except Exception as A:log('Error starting daemons: %s'%A)
if __name__=='__main__':main()
EOL

# start daemon script
python $DAEMON_SCRIPT >> $LOG_FILE 2>&1 &

# create alias to disable SSL validation for "aws" cli
aws_orig=$(which aws 2> /dev/null)
function aws() {
    $aws_orig --no-verify-ssl $*
}
export -f aws

# TODO: terrible hack to get CDK stacks with this library to work:
# https://github.com/aws/aws-cdk/blob/1b29ca8e8805fe47eb534d2f564d18ca297e956f/packages/@aws-cdk/aws-s3-deployment/lib/lambda/index.py#L186
if [ -e /var/task/index.py ] && [ -e /opt/awscli/aws ]; then
    sed -i 's|check_call(\[aws\] + list|check_call(["/opt/awscli/aws", "--no-verify-ssl"] + list|g' /var/task/index.py
fi
# disable SSL validation for AWS SDK clients (TODO: should be done for all runtimes!)
if [ -e /var/runtime/boto3/session.py ]; then
    sed -i 's|verify=None|verify=False|g' /var/runtime/boto3/session.py
fi

if [ "$LOCALSTACK_DEBUG" = "1" ]; then
  tail -f $LOG_FILE &
fi

docker_host=$LOCALSTACK_HOSTNAME

# set iptables route to instance metadata service
iptables -t nat -A OUTPUT -d 169.254.169.254 -j DNAT --to-destination $docker_host 2> /dev/null

# configure host names in /etc/hosts
if [ "$docker_host" = "" ]; then
  docker_host=$(python -c 'import socket; print(socket.gethostbyname_ex("host.docker.internal")[2][0])')
fi
if [ "$docker_host" != "" ]; then
  echo "$docker_host localhost.localstack.cloud" >> /etc/hosts
  if [ "$LOCALSTACK_HOSTS_ENTRY" != "" ]; then
    echo INIT: "Host '$LOCALSTACK_HOSTS_ENTRY' resolves to '$docker_host'"
    echo "$docker_host $LOCALSTACK_HOSTS_ENTRY" >> /etc/hosts
  fi
fi

old_entrypoint="/var/rapid/init --bootstrap /var/runtime/bootstrap"
new_entrypoint="$old_entrypoint"
if [[ "$_LAMBDA_RUNTIME" == provided* ]]; then
  new_entrypoint=/var/task/bootstrap
  if [ -e /opt/bootstrap ]; then
    new_entrypoint=/opt/bootstrap
  fi
fi

if [ "$LAMBDA_XRAY_INIT" = "1" ]; then
  # sleep a bit before and after the command, to make sure we receive the XRay records
  sleep 0.8
fi
if [ `gosu $LAMBDA_USER echo 2> /dev/null` ]; then
  gosu $LAMBDA_USER $new_entrypoint "$@"
else
  $new_entrypoint "$@"
fi
CODE=$?
if [ "$LAMBDA_XRAY_INIT" = "1" ]; then
  # sleep a bit before and after the command, to make sure we receive the XRay records
  sleep 0.6
fi
exit $CODE