

#for i in $(ls -l _posts/ | grep -vi total | tac | awk '{print $NF}' | head -n 10) ; do echo '-'; echo -n "  filename: '";head -n2 _posts/$i | tail -n1 | awk '{print $NF}'| tr -d '"'| tr -d '\n';echo "'";echo -n "  lastmod: '";head -n3 _posts/$i | tail -n1 | awk '{print $1="",$0}'| tr -s ' '| tr -d '\n'| cut -c2- | tr -d '\n'; echo "'"; done > _data/updates.yml 


ls -l _posts/ | grep -vi total | tac | tr -s ' '| cut -d ' ' -f 9- | head -n 10 > ./recent-updates-mds

while read i;do
echo '-';
echo -n "  filename: '";
#head -n2 "_posts/$i" | tail -n1 | awk '{print $NF}'| tr -d '"'| tr -d '\n';
head -n2 "_posts/$i" | tail -n1| tr -d '"' | sed 's/title: //g' | tr -d '\n';
echo "'";
echo -n "  lastmod: '";
head -n3 "_posts/$i" | tail -n1 | awk '{print $1="",$0}'| tr -s ' '| tr -d '\n'| cut -c2- | tr -d '\n';
echo "'";
done < recent-updates-mds > _data/updates.yml
