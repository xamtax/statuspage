USER_NAME=$1
USER_EMAIL=$2
TELEGRAM_API_KEY=$3

commit=true
origin=$(git remote get-url origin)

KEYSARRAY=()
URLSARRAY=()

urlsConfig="./urls.cfg"
echo "Reading $urlsConfig"
while read -r line
do
  txtUrl=${line#*=}
  txtName=${line%"=$txtUrl"}

  echo "[${txtName}] with [URL: ${txtUrl}]"

  KEYSARRAY+=(${txtName})
  URLSARRAY+=(${txtUrl})
done < "$urlsConfig"


echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs

for (( index=0; index < ${#KEYSARRAY[@]}; index++))
do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  echo "  $key=$url"

  for i in 1 2 3 4;
  do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null $url)
    if [ "$response" -eq 200 ] || [ "$response" -eq 202 ] || [ "$response" -eq 301 ] || [ "$response" -eq 302 ] || [ "$response" -eq 307 ]; then
      result="success"
    else
      result="failed"
      response=$(curl --location --request POST "https://api.telegram.org/bot${TELEGRAM_API_KEY}/sendMessage?chat_id=-1002249059855&text=%F0%9F%9A%A8%20%2A%24%7Bkey%7D%2A%20is%20currently%20down%20%7C%20https%3A%2F%2Fxamtax.github.io%2Fstatuspage%2F" \
                 --header 'Content-Type: application/json' \
                 --silent --output /dev/null $url)
    fi
    if [ "$result" = "success" ]; then
      break
    fi
    sleep 5
  done
  dateTime=$(date +'%Y-%m-%d %H:%M')
  if [[ $commit == true ]]
  then
    echo $dateTime, $result >> "logs/${key}_report.log"
    # By default we keep 2000 last log entries.  Feel free to modify this to meet your needs.
    echo "$(tail -2000 logs/${key}_report.log)" > "logs/${key}_report.log"
  else
    echo "    $dateTime, $result"
  fi
done

if [[ $commit == true ]]
then
  git config --global user.name "${USER_NAME}"
  git config --global user.email "${USER_EMAIL}"

  git add -A --force logs/
  git commit -am '[Automated] Update Health Check Logs'
  git push
fi
