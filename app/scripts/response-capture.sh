# This is script can be deployed on the curl container to capture
# and avg the response time of the httpbin service to notice delays
# due to the ext_authz filter
#!/bin/bash

total_time=0
count=0

while true; do
  # change the curl endpoint to appropriate service as needed
  response_time=$( { time curl -o /dev/null -s -w '%{time_total}\n' curl -i httpbin.default.svc.cluster.local/headers -H "x-api-key: ${APIGEE_DEV_API_KEY}"; } 2>&1 )
  total_time=$(echo "$total_time + $response_time" | bc -l)
  count=$((count + 1))
  average_time=$(echo "$total_time / $count" | bc -l)
  echo "Response Time: $response_time seconds"
  echo "Average Response Time: $average_time seconds"
  usleep 25000 # Sleep for 25 milliseconds (25,000 microseconds)
done
