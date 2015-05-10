use IO::Pipe;
use POSIX qw(:sys_wait_h);
use Fcntl ':flock';

$SIG{ALRM}=sub {
   die 'alarm';
};

$SIG{INT}=sub{
   if($i==($n+1)){
      1 while (waitpid(-1, WNOHANG) > 0);
   }
   else{
      close($in); 
      close($in2); 
      close($in3); 
      close($in4);  
      close($in5);  
      close($in6);  
   }
   exit;
};

$\="\n";
print "Enter number of forks";
$n=<>;
$i=1;
my (@pip,@pip2); #@pip - master reads, children write; @pip2 - vice versa

while($i<=$n){
   $pip[$i]=IO::Pipe->new();
   $pip2[$i]=IO::Pipe->new();
   last if fork()==0;
   ++$i;
}


if($i>$n) {#only for master
   my $k=1;

   while($k<=$n){
      $pip[$k]->reader();
      my $pi=$pip[$k];
      my $success=<$pi>; #master receives info, that children are ready
      chomp($success);
      if($success ne'1'){
         print "error $k";
         print "enter Ctrl+C to exit";
         1 while <>;
      }
      ++$k;
   }

   $k=1;

   while($k<=$n){
      $pip2[$k]->writer();
      $pip2[$k]->autoflush(1);
      print {$pip2[$k]} "1"; # master tells children, that all children are ready and they can start
      ++$k;
   }

   while(1){
      sleep(60);
      my $winner;
      my $maxres=0;
      $k=1;
      
      while($k<=$n){
         print {$pip2[$k]} "1";#master says that he wants to get stats
         ++$k;
      }

      $k=1;
      
      while($k<=$n){
         my $pi=$pip[$k];
         my $theyAreReady=<$pi>; #children inform master, that they stopped. it is for synchronyzing
         ++$k;
      }
      
      
      $k=1;
     
      while($k<=$n){
         print {$pip2[$k]} "1"; #master inform children that other children stopped and that they can send stats
         ++$k;
      }

      $k=1;
      
      while($k<=$n){
         my $pi=$pip[$k];
         my $res=<$pi>; #receiving stats
         chomp($res);
         if($res>$maxres){
            $maxres=$res;
            print "$k res=$res";
            $winner=$k;
         }
         ++$k;
      } 

      print "winner is fork number $winner";
   }
}

else{ #for children, not for master
   open($in,">","forkgame$i.txt");
   my $k=0;
   $\='';

   while($k<$n){
      print $in chr(33+$k);#filling empty files with symbols from ASCII
      ++$k;
   }

   close($in);
   $\="\n";
   $pip[$i]->writer();
   $pip[$i]->autoflush(1);
   print {$pip[$i]} "1";
   $pip2[$i]->reader();
   my $pi=$pip2[$i];
   my $start=<$pi>;#children get information that other children also are ready

   while(1){
      my $statTime=0;#time for calculating and sending stats
      alarm(1);
      eval{
         $statTime=<$pi>;
      };
      alarm(0);
      if($statTime){
         open(my $in,"<","forkgame$i.txt");
         flock($in,LOCK_SH);
         print {$pip[$i]} "1";#here we tell master that we stopped
         my $ready=<$pi>;#here we understand that other children also stopped
         my $points= result("forkgame$i.txt");#calculate stats
         close($in);
         print {$pip[$i]} $points;#sending stats 
      }

      my $num;
      while(1){# in this loop we try to get full access to two files. it might be impossible because of possible dead-lock
         alarm(1);
         eval{
            $num=random($i-1)+1;
            open($in,">>","forkgame$i.txt");
            flock($in,LOCK_EX);
            open($in2,">>","forkgame$num.txt");
            flock($in2,LOCK_EX);
         };
         alarm(0);
         last if !$@;
      }
      open($in5,"<","forkgame$i.txt");
      open($in6,"<","forkgame$num.txt");
      my $me=<$in5>;
      my $notme=<$in6>;

      my $changeNum=random($n);
      my $changeNum2=random($n);
      my $tmp=substr($me,$changeNum,1);
      substr($me,$changeNum,1)=substr($notme,$changeNum2,1);
      substr($notme,$changeNum2,1)=$tmp;

      open($in3,">","forkgame$i.txt");
      open($in4,">","forkgame$num.txt");
      print $in3 $me;
      print $in4 $notme;

      close($in3); 
      close($in4);  
      close($in5);  
      close($in6);  
      close($in); 
      close($in2); 
   }
}

sub random{
   my $j=shift;
   my $generate=$j;
   while($generate==$j){
      $generate=int(rand($n));
   }
   return $generate;
}

sub result{
   my $filename=shift;
   open(my $in,"<",$filename);
   flock($in,LOCK_SH);
   my %hash;
   my $line=<$in>;
   my $j=0;
   while($j<$n){
      ++$hash{substr($line,$j,1)};
      ++$j;
   }
   $j=0;
   my $max=0;
   while($j<$n){
      $max=$hash{chr(33+$j)} if $max<$hash{chr(33+$j)};
      ++$j;
   }
   return $max;
}
