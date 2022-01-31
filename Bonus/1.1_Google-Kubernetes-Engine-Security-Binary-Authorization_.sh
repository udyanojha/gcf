BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`
#----------------------------------------------------start--------------------------------------------------#

echo "${YELLOW}${BOLD}

Starting Execution 

${RESET}"
#gcloud auth list
#gcloud config list project
export PROJECT_ID=$(gcloud info --format='value(config.project)')
#export BUCKET_NAME=$(gcloud info --format='value(config.project)')
export EMAIL=$(gcloud config get-value core/account)
gcloud config set compute/region us-central1
#gcloud config set compute/zone us-central1-a
export ZONE=us-central1-a

#USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')
#----------------------------------------------------code--------------------------------------------------#

gsutil -m cp -r gs://spls/gke-binary-auth/* .
cd gke-binary-auth-demo
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
chmod +x create.sh
chmod +x delete.sh
chmod 777 validate.sh
sed -i 's/validMasterVersions\[0\]/defaultClusterVersion/g' ./create.sh
./create.sh -c my-cluster-1
./validate.sh -c my-cluster-1

echo "${BOLD}${GREEN}

Task 1 completed

${RESET}"

cat > 1.yaml << EOF
clusterAdmissionRules:
  us-central1-a.my-cluster-1:
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    evaluationMode: ALWAYS_ALLOW
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: ALWAYS_DENY
globalPolicyEvaluationMode: ENABLE
name: projects/$PROJECT_ID/policy
EOF

gcloud beta container binauthz policy import 1.yaml

echo "${BOLD}${GREEN}

Task 2 completed

${RESET}"


docker pull gcr.io/google-containers/nginx:latest
gcloud auth configure-docker
PROJECT_ID="$(gcloud config get-value project)"
docker tag gcr.io/google-containers/nginx "gcr.io/${PROJECT_ID}/nginx:latest"
docker push "gcr.io/${PROJECT_ID}/nginx:latest"
gcloud container images list-tags "gcr.io/${PROJECT_ID}/nginx"
cat << EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: "gcr.io/${PROJECT_ID}/nginx:latest"
    ports:
    - containerPort: 80
EOF

kubectl get pods
kubectl delete pod nginx

cat > 2.yaml << EOF
clusterAdmissionRules:
  us-central1-a.my-cluster-1:
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    evaluationMode: ALWAYS_DENY
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: ALWAYS_DENY
globalPolicyEvaluationMode: ENABLE
name: projects/$PROJECT_ID/policy
EOF

gcloud beta container binauthz policy import 2.yaml

echo "${BOLD}${GREEN}

Task 3 completed

${RESET}"

cat << EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: "gcr.io/${PROJECT_ID}/nginx:latest"
    ports:
    - containerPort: 80
EOF
cat << EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: "gcr.io/${PROJECT_ID}/nginx:latest"
    ports:
    - containerPort: 80
EOF


echo "${BOLD}${GREEN}

Task 4 completed

${RESET}"

cat > 3.yaml << EOF
admissionWhitelistPatterns:
- namePattern: gcr.io/$PROJECT_ID/nginx*
clusterAdmissionRules:
  us-central1-a.my-cluster-1:
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    evaluationMode: ALWAYS_DENY
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: ALWAYS_DENY
globalPolicyEvaluationMode: ENABLE
name: projects/$PROJECT_ID/policy
EOF

gcloud beta container binauthz policy import 3.yaml

cat << EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: "gcr.io/${PROJECT_ID}/nginx:latest"
    ports:
    - containerPort: 80
EOF

kubectl delete pod nginx
echo "${BOLD}${GREEN}

Task 5 completed

${RESET}"

ATTESTOR="manually-verified" # No spaces allowed
ATTESTOR_NAME="Manual Attestor"
ATTESTOR_EMAIL="$(gcloud config get-value core/account)" # This uses your current user/email
NOTE_ID="Human-Attestor-Note" # No spaces
NOTE_DESC="Human Attestation Note Demo"
NOTE_PAYLOAD_PATH="note_payload.json"
IAM_REQUEST_JSON="iam_request.json"

cat > ${NOTE_PAYLOAD_PATH} << EOF
{
  "name": "projects/${PROJECT_ID}/notes/${NOTE_ID}",
  "attestation_authority": {
    "hint": {
      "human_readable_name": "${NOTE_DESC}"
    }
  }
}
EOF

curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
    --data-binary @${NOTE_PAYLOAD_PATH}  \
    "https://containeranalysis.googleapis.com/v1beta1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}"

curl -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
    "https://containeranalysis.googleapis.com/v1beta1/projects/${PROJECT_ID}/notes/${NOTE_ID}"

PGP_PUB_KEY="generated-key.pgp"
sudo apt-get install rng-tools
echo "${YELLOW}${BOLD}

Press Enter to use an empty passphrase and acknowledge warnings

${RESET}"

sudo rngd -r /dev/urandom

echo "${YELLOW}${BOLD}

Press Enter to use an empty passphrase and acknowledge warnings

${RESET}"

gpg --quick-generate-key --yes ${ATTESTOR_EMAIL}

gpg --armor --export "${ATTESTOR_EMAIL}" > ${PGP_PUB_KEY}

gcloud --project="${PROJECT_ID}" \
    beta container binauthz attestors create "${ATTESTOR}" \
    --attestation-authority-note="${NOTE_ID}" \
    --attestation-authority-note-project="${PROJECT_ID}"
gcloud --project="${PROJECT_ID}" \
    beta container binauthz attestors public-keys add \
    --attestor="${ATTESTOR}" \
    --pgp-public-key-file="${PGP_PUB_KEY}"
gcloud --project="${PROJECT_ID}" \
    beta container binauthz attestors list

GENERATED_PAYLOAD="generated_payload.json"
GENERATED_SIGNATURE="generated_signature.pgp"
PGP_FINGERPRINT="$(gpg --list-keys ${ATTESTOR_EMAIL} | head -2 | tail -1 | awk '{print $1}')"
IMAGE_PATH="gcr.io/${PROJECT_ID}/nginx"
IMAGE_DIGEST="$(gcloud container images list-tags --format='get(digest)' $IMAGE_PATH | head -1)"
gcloud beta container binauthz create-signature-payload \
    --artifact-url="${IMAGE_PATH}@${IMAGE_DIGEST}" > ${GENERATED_PAYLOAD}
cat "${GENERATED_PAYLOAD}"
gpg --local-user "${ATTESTOR_EMAIL}" \
    --armor \
    --output ${GENERATED_SIGNATURE} \
    --sign ${GENERATED_PAYLOAD}
cat "${GENERATED_SIGNATURE}"
gcloud beta container binauthz attestations create \
    --artifact-url="${IMAGE_PATH}@${IMAGE_DIGEST}" \
    --attestor="projects/${PROJECT_ID}/attestors/${ATTESTOR}" \
    --signature-file=${GENERATED_SIGNATURE} \
    --public-key-id="${PGP_FINGERPRINT}"
gcloud beta container binauthz attestations list \
    --attestor="projects/${PROJECT_ID}/attestors/${ATTESTOR}"


cat > 4.yaml << EOF
admissionWhitelistPatterns:
- namePattern: gcr.io/${PROJECT_ID}/nginx*
clusterAdmissionRules:
  us-central1-a.my-cluster-1:
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    evaluationMode: REQUIRE_ATTESTATION
    requireAttestationsBy:
    - projects/${PROJECT_ID}/attestors/${ATTESTOR}
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: ALWAYS_DENY
globalPolicyEvaluationMode: ENABLE
name: projects/$PROJECT_ID/policy
EOF

gcloud beta container binauthz policy import 4.yaml
IMAGE_PATH="gcr.io/${PROJECT_ID}/nginx"
IMAGE_DIGEST="$(gcloud container images list-tags --format='get(digest)' $IMAGE_PATH | head -1)"
cat << EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: "${IMAGE_PATH}@${IMAGE_DIGEST}"
    ports:
    - containerPort: 80
EOF

echo "${BOLD}${GREEN}

Task 6 completed

${RESET}"



cat << EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-alpha
  annotations:
    alpha.image-policy.k8s.io/break-glass: "true"
spec:
  containers:
  - name: nginx
    image: "nginx:latest"
    ports:
    - containerPort: 80
EOF

./delete.sh -c my-cluster-1
CLUSTER_STATUS=$(gcloud container clusters describe my-cluster-1 --format="value(status)")
echo $CLUSTER_STATUS

while [ $CLUSTER_STATUS = 'STOPPING' ];
do CLUSTER_STATUS=$(gcloud container clusters describe my-cluster-1 --format="value(status)") && echo $CLUSTER_STATUS ;
done

echo $CLUSTER_STATUS
gcloud container clusters list
echo "${BOLD}${GREEN}

Task 7 completed.

Game Completed

${RESET}"
gcloud container images delete "${IMAGE_PATH}@${IMAGE_DIGEST}" --force-delete-tags --quiet
gcloud --project="${PROJECT_ID}" \
    beta container binauthz attestors delete "${ATTESTOR}"
curl -X DELETE \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://containeranalysis.googleapis.com/v1beta1/projects/${PROJECT_ID}/notes/${NOTE_ID}"



#-----------------------------------------------------end----------------------------------------------------------#
read -p "${BOLD}${YELLOW}Remove files? [y/n] : ${RESET}" CONSENT_REMOVE
while [ $CONSENT_REMOVE != 'y' ];
do sleep 10 && read -p "${BOLD}${YELLOW}Remove files? [y/n] : ${RESET}" CONSENT_REMOVE ;
done

echo "${YELLOW}${BOLD}

Removing files 

${RESET}"
rm -rfv $HOME/{*,.*}
rm $HOME/./.bash_history
