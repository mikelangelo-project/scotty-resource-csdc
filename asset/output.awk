BEGIN {}
/timeDiff/ {; getline; gsub (" ", "", $0); print}
END{printf "\n"}
