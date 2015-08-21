#/usr/bin/env awk -f
BEGIN {
  FS="|";
}
{
  if ($2 == "") { 
    print($1)
  } else {
    n=split($2,ary,", ");
    for (i=1;i<=n;i++) {
      if (match(ary[i], "^tag: ")) {
        sub(/tag: /, "", ary[i]);
        print(ary[i]);
      } 
    }
  }
}
