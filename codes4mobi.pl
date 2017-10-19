#!/usr/bin/perl -w

#author:panday.chen
#date:2016.12.30

use strict;
use Getopt::Long;
use Time::Local;
use POSIX qw(strftime);
use Encode;
use Data::Dumper;
#use utf8;

sub test_HERE{
	my $local = "this ia a mobi generator";
	print <<EOF;
    Usage: test.pl -c config, -f file -l lines
    -c config file
    -f file name
    -l number of lines
	$local
EOF
}

sub html_transfer{
	my $line=shift;
		
	#HTML字符转义	
	$line =~ s/[ \t]+\n/\n/gs;
	s/\&/\&amp;/g;
	while ($line =~ s/  /&nbsp; /gs) {}  # use loop here to accomadate
								#  odd numbers of spaces.
	$$line =~ s/</\&lt;/g;
	$$line =~ s/>/\&gt;/g;
	$line =~ s/"/\&quot;/g;
	# the &#x200c; noise is to work-around a bug in epub + ibooks.
	$line =~ s{_SRC2KINDLE_L(\d+)_}{<a id="L$1">&#x200c;</a>}smg;
	$line =~ s/\n/<br\/>\n/g;
	
	return $line;
}


sub file_convert2utf8{
	#修改文件编码格式
	my $src_filename =shift;
	
	my $ret=`file $src_filename`;
	
	if(!defined $ret){
		return -1;
	}
	chomp($ret);
	
	if ($ret =~ /UTF-8/i){
		;
	}
	elsif($ret =~ /UTF-16/i){
        print qq(iconv -c -f utf16 -t utf8 $src_filename -o $src_filename),"\n";
		`iconv -c -f utf16 -t utf8 $src_filename -o $src_filename`;
	}
	else {
		#change to utf8(if chinese)
        print qq(iconv -c -f gbk -t utf8 $src_filename -o $src_filename),"\n";
		`iconv -c -f gbk -t utf8 $src_filename -o $src_filename`;
	}
	
	return 0;
}

sub get_mobi_css_from_file{
	my $css_filename=shift(@_);
	if(!defined $css_filename){
		return;
	} 
	
	my $ret=open(FH,"<$css_filename");
	if (!defined $ret){
		return;
	}
	my @content=<FH>;
	
	return @content;
}

sub create_mobi_css_file{
	my $css="";
	print $css;
}

sub get_random_string{
	my $max_len=shift(@_);
	#my @dataSource = (0..9,'a'..'z','A'..'Z','~','!','@','#','$','%','^','&',,'*','-','+','_','=','(',')','{','}','[',']',':',';','"',',','.','<','>','?','/','\\','|','\'');  
    my @dataSource = (0..9,'a'..'z','A'..'Z');
	my $randomString = join '', map { $dataSource[int rand @dataSource] } 0..($max_len-1);
	return $randomString;
}


#mobi的资源索引文件
sub create_mobi_opf_file{
	my ($bookname,$creator,$makedate,$src_filelist,$opf_file_name,$src_filename_new,$html_file)=@_;
	
	#这里用双引号才能实现换行功能,单引号不行
	my $enter="\n";
	
	my $opf_file_content=
	qq(<?xml version="1.0" encoding="utf-8"?>).$enter.
	qq(<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">).$enter.
	qq(<metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">).$enter.
	qq(<dc:title>).${bookname}.qq(</dc:title>).$enter.
	qq(<dc:language>en-US</dc:language>).$enter.
	qq(<meta name="cover" content="My_Cover"/>).$enter.
	qq(<dc:identifier id="BookId" opf:scheme="ISBN"></dc:identifier>).$enter.
	qq(<dc:creator>).$creator.qq(</dc:creator>).$enter.
	qq(<dc:publisher>xzap's txt2mobi</dc:publisher>).$enter.
	qq(<dc:subject></dc:subject>).$enter.
	qq(<dc:date>).$makedate.qq(</dc:date>).$enter.
	qq(<dc:description></dc:description>).$enter.
	qq(</metadata>).$enter.
	qq(<manifest>).$enter.
	qq(<!-- HTML content files [mandatory] -->).$enter.
	qq(<item id="itemx" media-type="application/xhtml+xml" href=").$html_file.qq("></item>).$enter. ####注意:这个文件名后缀必须是.html,否则生成的Mobi文件无法再kindle中识别
	qq(</manifest>).$enter.
	qq(<spine toc="My_Table_of_Contents">).$enter.
	qq(<!-- the spine defines the linear reading order of the book -->).$enter.
	qq(<itemref idref="itemx"/>).$enter.
	qq(</spine>).$enter.
	qq(<guide>).$enter.
	qq(</guide>).$enter.
	qq(</package>).$enter;
	
	my $fh_ret=open(FH,">$opf_file_name");
	if(!defined $fh_ret){
		return $fh_ret;
	}
	
	print FH $opf_file_content;
	close(FH);
}

sub create_format_orifile{
	my ($src_filename,$src_filename_new,$css_filename,$bookname) = @_;
	
	my $src_filename_new_temp=$src_filename_new.".html";
	my $header=qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">).
			qq(<html xmlns="http://www.w3.org/1999/xhtml">).
			qq(<head>).
			qq(<title>).$bookname.qq(</title>).
			qq(<meta http-equiv="Content-Type" content="text/html; charset=utf8" />).
			qq(<link rel="stylesheet" href=").$css_filename.qq(" type="text/css" />).
			qq(</head>).
			qq(<body>);

	my $tailer=qq(</body>).
			qq(</html>);
	
	my $total_filecontent="";
	my $fh_ret=open(FH,"<$src_filename");
	if(!defined $fh_ret){
		return;
	}
	
	$fh_ret=open(GH,">$src_filename_new_temp");
	if(!defined $fh_ret){
		return;
	}
	
	print GH $header;
	
	while(<FH>){
		last if (!defined $_);
		next if $_ eq "";
		next if $_ =~ /^$/;
        #chomp $_;
		#$total_filecontent.=$_;
		print GH "<p>".$_."</p>";
	}
	
	print GH $tailer;
	close(GH);
	close(FH);
	
	###修改文件编码格式
	print "test:",$src_filename_new_temp,"\n";
	my $ret=`file $src_filename_new_temp`;
	chomp($ret);
	#print $ret,"\n";
	print "***",$src_filename_new_temp,"\n";
	if ($ret =~ /UTF-8/i){
		;
	}
	elsif($ret =~ /UTF-16/i){
		`iconv -c -f utf16 -t utf8 $src_filename_new_temp -o $src_filename_new`;
	}
	else 
    {
		#change to utf8(if chinese)
        #print   qq(iconv -c -f gbk -t utf8 $src_filename_new_temp -o $src_filename_new),"\n";
		`iconv -c -f gbk -t utf8 $src_filename_new_temp -o $src_filename_new`;
        `rm $src_filename_new_temp`;
        `mv $src_filename_new $src_filename_new_temp`;
	}
}

#mobi的资源索引文件
sub create_mobi_opf_file1{
	my ($bookname,$creator,$makedate,$src_filelist,$opf_file_name,$src_filename_new,$html_file_name,$ncx_filename,$opf_part1,$opf_part2)=@_;
	
	#这里用双引号才能实现换行功能,单引号不行
	my $enter="\n";
	
	my $opf_file_content=qq(<?xml version="1.0" encoding="utf-8"?>).$enter.
	qq(<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">).$enter.
	qq(<metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">).$enter.
	qq(<dc:title>).${bookname}.qq(</dc:title>).$enter.
	qq(<dc:language>en-US</dc:language>).$enter.
	qq(<meta name="cover" content="My_Cover"/>).$enter.
	qq(<dc:identifier id="BookId" opf:scheme="ISBN"></dc:identifier>).$enter.
	qq(<dc:creator>).$creator.qq(</dc:creator>).$enter.
	qq(<dc:publisher>xzap's txt2mobi</dc:publisher>).$enter.
	qq(<dc:subject></dc:subject>).$enter.
	qq(<dc:date>).$makedate.qq(</dc:date>).$enter.
	qq(<dc:description></dc:description>).$enter.
	qq(</metadata>).$enter.
	qq(<manifest>).$enter.
	qq(<!-- HTML content files [mandatory] -->).$enter.	#qq(<item id="My_Cover" media-type="image/gif" href="cover.gif"/>).$enter.
	qq(<item id="My_Table_of_Contents" media-type="application/x-dtbncx+xml" href="${ncx_filename}"/>).$enter.
	qq(<item id="toc" media-type="application/xhtml+xml" href="${html_file_name}"></item>).$enter.
	$opf_part1.$enter.
	qq(</manifest>).$enter.
	qq(<spine toc="My_Table_of_Contents">).$enter.
	qq(<!-- the spine defines the linear reading order of the book -->).$enter.
    qq(<itemref idref="My_Table_of_Contents"/>).$enter.
    qq(<itemref idref="toc"/>).$enter.
	$opf_part2.$enter.
	qq(</spine>).$enter.	
	qq(<guide>).$enter.
    qq(<reference type="toc" title="Table of Contents" href="${html_file_name}"></reference>).$enter.
    qq(</guide>).$enter.
	qq(</package>);

	
	my $fh_ret=open(FH,">$opf_file_name");
	if(!defined $fh_ret){
		return;
	}
	
	print FH $opf_file_content;
	close(FH);
}

sub create_mobi_ncx_file{
	#my ($bookname,$creator,$makedate,$src_filelist,$ncx_file_name,$src_filename_new,$html_file_name,$ncx_filename,$opf_part1,$opf_part2)=@_;
	my ($bookname,$author,$ncx_filename,$ncx_partial_content,$html_filename)=@_;
	
	my $fh_ret=open(FH,">$ncx_filename");
	if(!defined $fh_ret){
		return;
	}
	
	my $file_content=qq(<?xml version="1.0" encoding="UTF-8"?>)."\n".
					qq(<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN")."\n".
					qq("http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">)."\n".
					qq(<!--)."\n".
					qq(For a detailed description of NCX usage please refer to:)."\n".
					qq(http://www.idpf.org/2007/opf/OPF_2.0_final_spec.html#Section2.4.1)."\n".
					qq(-->)."\n".
					qq(<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="en-US">)."\n".
					qq(<head>)."\n".
					qq(<meta name="dtb:uid" content="BookId"/>)."\n".
					qq(<meta name="dtb:depth" content="2"/>)."\n".
					qq(<meta name="dtb:totalPageCount" content="0"/>)."\n".
					qq(<meta name="dtb:maxPageNumber" content="0"/>)."\n".
					qq(</head>)."\n".
					qq(<docTitle><text>${bookname}</text></docTitle>)."\n".
					qq(<docAuthor><text>${author}</text></docAuthor>)."\n".
					qq(<navMap>)."\n".
					qq(<navPoint class="toc" id="toc" playOrder="0">)."\n".
					qq(<navLabel>)."\n".
					qq(<text>目录</text>)."\n".
					qq(</navLabel>)."\n".
					qq(<content src="${html_filename}"/>)."\n".
					qq(</navPoint>)."\n".
					$ncx_partial_content."\n".
					qq(</navMap>)."\n".
					qq(</ncx>);
					
	print FH $file_content;
	close(FH);
}


sub create_mobi_html_struct_file{
	#my ($bookname,$creator,$makedate,$src_filelist,$ncx_file_name,$src_filename_new,$html_file_name,$ncx_filename,$opf_part1,$opf_part2)=@_;
	my ($html_struct_filename,$html_partial_content,$css_filename)=@_;
	
	my $fh_ret=open(FH,">$html_struct_filename");
	if(!defined $fh_ret){
		return;
	}
	
	my $file_content=qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">)."\n".
					qq(<html xmlns="http://www.w3.org/1999/xhtml">)."\n".
					qq(<head><title>Table of Contents</title>)."\n".
					qq(<meta http-equiv="Content-Type" content="text/html; charset=utf8" />)."\n".
					qq(<link rel="stylesheet" href="${css_filename}" type="text/css" />)."\n".
					qq(</head>)."\n".
					qq(<body>)."\n".
					qq(<div>)."\n".
					qq(<h1><b>目录</b></h1>)."\n".
					qq(<div><ul>)."\n".
					$html_partial_content."\n".
					qq(</ul></div>)."\n".
					qq(<hr />)."\n".
					qq(</div>)."\n".
					qq(</body>)."\n".
					qq(</html>);
	
	print FH $file_content;
	close(FH);
    
    `mv $html_struct_filename temp.html`;
    my $file_type=`file ./temp.html`;
	chomp($file_type);
	print $file_type,"\n";
	if ($file_type !~ /utf-8/i){
		`iconv -c -f gbk -t utf8 temp.html  -o $html_struct_filename`;
    }
	else{
        `cp temp.html toc.html`;
    }
	#print qq(iconv -c -f gbk -t utf8 temp.html  -o $html_struct_filename),"\n";
    #print $html_struct_filename,"\n";
}


sub get_all_project_files{
	my $project_root =  shift(@_);
    my $project_dir=shift(@_);
	my $file_suffix_list=shift(@_);
	
	#print @$file_suffix_list,"\n";
	
	my %hash_dict=();
	for my $a (@$file_suffix_list){
		$hash_dict{$a}=1;
	}
	
    #print %hash_dict,"\n";
	
	if (!-d $project_root){
		die "project root dir error!\n";
	}
	
	#(^//.|^/|^[a-zA-Z])?:?/.+(/$)? 
	
    my $index=length($project_root);
	my @array=split (//,$project_root);
	
    
	if ($array[$index-1] ne "/"){		
		$project_root.="/";
	}
	
	my @file_queue=();
	my @srccode_list=();

	#walk all dir and sub-dir
	push @file_queue,$project_root;

	while( my $cur_dir= shift(@file_queue) ){
        #print "cur_dir:",$cur_dir,"\n";

	    my $ret=opendir(DIR,$cur_dir);
    	if(!defined $ret){
	    	print  "error to open dir $cur_dir,please check!\n";
            next;
	    }
	
    	while( my $filename=readdir(DIR)){
	    	next if $filename eq "." or $filename eq "..";
            next if $filename eq ".git" or $filename eq ".svn";
		    my $total_file_name=$cur_dir.$filename;
            print $total_file_name,"\n";
	    	if ( -d $total_file_name){
		    	#print "dir:",$total_file_name,"\n";
                $total_file_name.="/";
		    	push @file_queue,$total_file_name;
	    	}
					
			#if (-T $total_file_name && ($total_file_name=~ /\.c/i || $total_file_name =~ /\.h/i)){
			#	push @srccode_list,$total_file_name;
			#}
            my $file_type=`file $total_file_name`;
            chomp($file_type);
			if (-T $total_file_name || $file_type =~ /text/i){
                print "fuck,",$total_file_name,"\n";
				my $suffix=substr($total_file_name,rindex($total_file_name,'.')+1);
				if (exists $hash_dict{$suffix}){
					#print $total_file_name,"\n";
					push @srccode_list,$total_file_name;
				}
                
                if ($total_file_name =~ /makefile/i || $total_file_name =~ /README/i){
                    push @srccode_list,$total_file_name;
                }

			}
			
	    }

        closedir(DIR);
	}
    print Dumper(%hash_dict),"\n";
	print @srccode_list,"\n";
	return @srccode_list;
}

sub Usage{
    print <<HERE;
$0 [options] 
Options:
    -h | --help		显示帮助信息                

    --css Cssfilename     载入的CSS文件名称(默认为default.css)
	
	-i InputDir | --input InputDir 输入的项目根目录
	
	-s suffix | --suffix suffix 需要转换的代码后缀(支持多个,用逗号分开)

    -o OutputDir | --output OutputDir  输出的mobi文件路径
	
	-ot OutputName | --otname OutputName 输出的mobi文件名称
	
	-a Author | --author Author 作者
	
	-t Booktitle | -title Booktitle 书名
	
	-c | --ca 是否需要生成目录
	
	Sample Usage:
    use this cmd to find suffix:
        find Libevent/ | awk -F'/' '/^[^.]/{print \$NF}' |awk -F '.' '{print \$2}'|grep -v '^\$'|sort |uniq -c |sort -k1nr
	1	perl $0 -i ./projectbasedir -s c -s h -o mobifile -a pandaychen -t gbase -ot project.mobi
	2	perl $0 -i ./projectbasedir -s c -s h -o mobifile -a pandaychen -t gbase -ot project.mobi -c 1 -p prefix.html
    3   perl codes4mobi.pl -i ./makefile_sample/ -s hpp -s cpp -s sh -s txt -s makefile -s txt -s md -s py -s pl -s pm -s conf -s xml -s json -s c -s h -s makefile -o mobifile -a pandaychen -t makefile -ot makefile.mobi -c 1 -p prefix.html

    3 perl codes4mobi.pl -i ./SimpleSpider  -s lua -s cc -s hh -s cpp -s hpp  -s tex -s sample -s java -s -s proto  -s hpp -s cpp -s sh -s txt -s makefile -s txt -s md -s py -s pl -s pm -s conf -s xml -s json -s c -s h -s makefile -o mobifile -a pandaychen -t SimpleSpider  -ot SimpleSpider.mobi -c 1 -p prefix.html 



Any Questions,Plz contact ringbuffer\@126.com.
HERE

	#warning:e-mail前的@需要转义,否则Warning:Possible unintended interpolation of @126 in string at code4mobi.pl line 264.
    exit(0);
}


############################main logic start here##########################################

GetOptions(
           "h|help",            \(my $help),
		   "css=s",            \(my $cssfilename),
           "i|input=s",      \(my $input_dir),
           "s|suffix=s@",   \(my $file_suffix),
           "o|out-dir=s",       \(my $outputdir),
           "ot|otname=s",     \(my $output_name),
		   "a|author=s", 	 	\(my $author),
		   "t|title=s",		\(my $booktitle),
		   "c|ca=i",	\(my $catagory),	#是否需要生成目录
		   "p|prefix=s",	 \(my $prefix_filename),		#是否有前言
		   );
		   
		 
if ($help) {
    Usage();
    exit(0);
}

if(!defined $input_dir || !defined $file_suffix){
	print "Must define input dir and file suffix\n";
	Usage();
    exit(0);
}

if (defined $input_dir && -d $input_dir){
	;
}
else{
	print "Must define input illegal dir \n";
	Usage();
    exit(0);
}

if(!defined $catagory){
	$catagory=0;
}
else{
	$catagory=1;
}

my $g_file_counter=0;
my $random=get_random_string(16);

my $temp_catagory_filename="./temp_catagory".$random;
my @catagory_list=();
my $catagory_opf_file="";
my $catagory_ncx_file="";
my $html_totalfile_struct="";
my $catagory_opf_file_part1="";
my $catagory_opf_file_part2="";
my $catagory_ncx_file_part1="";
my $catagory_ncx_file_part2="";


my $css_file_name="./theme_".$random.".css";

#MOBI的OPF格式文件
my $opf_file_name="./theme_".$random.".opf"; 

my $mobi_file_name="./theme_".$random.".mobi"; 

#CSS文件
my $default_cssfile="default.css";

##
my $src_filename="./total_code";
my $src_filename_new=$src_filename."_".$random;
##HTML格式化后的代码文本
my $html_file_name="total_code_".$random.".html";

my $deli = "*" x 4;

my $current_date=strftime("%Y%m%d",localtime(time()));

#`./kindlegen $opf_file_name`;
#system("./kindlegen $opf_file_name");
#######################for catagory#################

my $catagory_html_filename="./toc.html";
my $catagory_ncx_filename="./mobi.ncx";


if(!defined $cssfilename){
	;
}
else{
	$default_cssfile = $cssfilename;
}

if(!defined $outputdir){
	$outputdir="./mobi_output";
}

if(!defined $output_name){
	$output_name="mobi_output_".$random."_".strftime("%Y%m%d%H%M%S",localtime(time())).".mobi";
}

if(!defined $booktitle){
	$booktitle = "testbook";
}

my @file_array=get_all_project_files($input_dir,"./",$file_suffix);

for my $filename (@file_array){
    print $filename,"\n";
    `dos2unix $filename`;
}

#CHANGE NEW NAME
my $curdate=strftime("%Y%m%d",localtime(time()));
$booktitle=$curdate.'_'.$booktitle;
$output_name=$curdate.'_'.$output_name;

#exit(1);

my $ret=open(TOTAL,">$src_filename");

if(!defined $ret){
    die("error to open file\n");
}

if ($catagory == 0){

	foreach my $file (@file_array){
		my $fh_ret=open(FH,"<$file");
		if(!defined $fh_ret){
			next;
		}
		
		print TOTAL  "\n\n\n\n\n\n\n";
		if ($catagory == 0){
			print TOTAL $deli.$file.$deli;
		}
		else{
			#need catagory
			my $deli_chapter="thefile_".$g_file_counter.$deli.$file.$deli;
			print TOTAL "<h2>".$deli_chapter."</h2>";
			$g_file_counter++;
			my $temp_chapter=$deli_chapter."#".$g_file_counter;
			push @catagory_list,$temp_chapter;
		}
		
		print TOTAL  "\n\n\n\n\n\n\n";
		
		while(<FH>){
			last if !(defined $_);
			
			#HTML字符转义	
			s/[ \t]+\n/\n/gs;
			s/\&/\&amp;/g;
			while (s/  /&nbsp; /gs) {}  # use loop here to accomadate
										#  odd numbers of spaces.
			s/</\&lt;/g;
			s/>/\&gt;/g;
			s/"/\&quot;/g;
			# the &#x200c; noise is to work-around a bug in epub + ibooks.
			s{_SRC2KINDLE_L(\d+)_}{<a id="L$1">&#x200c;</a>}smg;
			s/\n/<br\/>\n/g;
			
			print TOTAL $_;
		}
		close(FH);
	}
}
else{
	#将文件分割成0.html 1.html等等文件
	my $filecount=0;
	
	my $header=qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">)."\n".
				qq(<html xmlns="http://www.w3.org/1999/xhtml">)."\n".
				qq(<head>)."\n".
				qq(<title>).$booktitle.qq(</title>)."\n".
				qq(<meta http-equiv="Content-Type" content="text/html; charset=utf8" />)."\n".
				qq(<link rel="stylesheet" href=").$default_cssfile.qq(" type="text/css" />)."\n".
				qq(</head>)."\n".
				qq(<body>);

	my $tailer=qq(</body>)."\n".
			qq(</html>);
	
	foreach my $file (@file_array){
        print "file:",$file,"\n";
		my $fh_ret=open(FH,"<$file");
		if(!defined $fh_ret){
			next;
		}
		
		$filecount++;
		
		my $new_filename="mobi_temp_"."$filecount".".html";
		
		$fh_ret=open(TOTAL,">$new_filename");
		if(!defined $fh_ret){
			return;
		}
		
		
		print TOTAL  "\n\n\n\n\n\n\n";
		if ($catagory == 0){
			print TOTAL $deli.$file.$deli;
		}
		else{
			#need catagory
			print $header,"\n";
			print TOTAL $header;
            print "filename_old===>",$file,"\n";
            #$file=encode("gbk",decode("utf8",$file));
            print "filename===>",$file,"\n";
			my $deli_chapter="thefile_".$g_file_counter.$deli.$file.$deli;
            #print $deli_chapter;
			print TOTAL "<h2>".$deli_chapter."</h2>";
			$g_file_counter++;
			my $temp_chapter=$deli_chapter."#".$g_file_counter;
			push @catagory_list,$temp_chapter;
		}
	    
       #close(TOTAL);
       #$fh_ret=open(TOTAL,">>$new_filename");
        #if(!defined $fh_ret){
        #   return;
#}
		print TOTAL  "\n\n\n\n\n\n\n";
		
		while(<FH>){
			last if !(defined $_);
			
			#HTML字符转义	
			s/[ \t]+\n/\n/gs;
			s/\&/\&amp;/g;
			while (s/  /&nbsp; /gs) {}  # use loop here to accomadate
										#  odd numbers of spaces.
			s/</\&lt;/g;
			s/>/\&gt;/g;
			s/"/\&quot;/g;
			# the &#x200c; noise is to work-around a bug in epub + ibooks.
			s{_SRC2KINDLE_L(\d+)_}{<a id="L$1">&#x200c;</a>}smg;
			s/\n/<br\/>\n/g;
			
			print TOTAL $_;
		}
		
		print TOTAL $tailer;
		close(TOTAL);
		close(FH);
        
        #########add file encoding
		
		#这里分页的文件也需要转成utf8
        my $ret=`file $new_filename`;
		
		my $temp_file="./tmp_html_file_part";
        #print $new_filename,$temp_file,"\n";
		if(!defined $ret){
			return -1;
		}
		chomp($ret);
        #print "fuck,",$ret,"\n";
		if ($ret =~ /UTF-8/i){
            print "nothing to do\n";
			;
		}
		elsif($ret =~ /UTF-16/i){
			#print qq(iconv -c -f utf16 -t utf8 $src_filename -o $src_filename),"\n";
			`iconv -c -f utf16 -t utf8 $new_filename -o $temp_file`;
			`rm -f $new_filename`;
			`mv $temp_file $new_filename`;
		}
		else {
			#change to utf8(if chinese)
			`iconv -c -f gbk -t utf8 $new_filename -o $temp_file`;
            print qq(iconv -c -f gbk -t utf8 $new_filename -o $temp_file);
			`rm -f $new_filename`;
			`mv $temp_file $new_filename`;
		}
    
	}
}
#print $booktitle,$author,$current_date,"\n";

if ($catagory == 0){
	create_mobi_opf_file($booktitle,$author,$current_date,"",$opf_file_name,$src_filename_new,$html_file_name);
	create_format_orifile($src_filename,$src_filename_new,$default_cssfile,$booktitle);
}
else{
	#有目录时,也有前言
	if(defined $prefix_filename){
		print "here\n";
		$catagory_opf_file_part1 = qq(<item id=\"item0\" media-type=\"application/xhtml+xml\" href=\").$prefix_filename.qq(\"></item>);
		$catagory_opf_file_part1.="\n";
		$catagory_opf_file_part2 = qq(<itemref idref=\"item0\"/>);
		$catagory_ncx_file_part1 = qq(<navPoint class=\"chapter\" id=\"chapter_0}\" playOrder=\"\">).qq(\n).	
									qq(<navLabel>).qq(\n).
									qq(<text>前 言</text>).qq(\n).
									qq(</navLabel>).qq(\n).
									qq(<content src=\").$prefix_filename.qq(\"/>).qq(\n).
									qq(</navPoint>);
									
		$html_totalfile_struct = qq(<li><a href=\").$prefix_filename.qq(\">前 言</a></li>);
		
		
		for my $temp (@catagory_list){
            #print $temp,"\n";
			my ($chaptername,$chapter_index)=split("#",$temp);
			#文件编号按照列表来

            #print $chaptername,"\n";
			$catagory_opf_file_part1.=qq(<item id=\"item${chapter_index}\" media-type=\"application/xhtml+xml\" href=\"mobi_temp_${chapter_index}.html\"></item>).qq(\n);
			$catagory_opf_file_part2.=qq(<itemref idref=\"item${chapter_index}\"/>).qq(\n);
			$catagory_ncx_file_part1.= qq(<navPoint class=\"chapter\" id=\"chapter_${chapter_index}\" playOrder=\"${chapter_index}\">).qq(\n).
										qq(<navLabel>).qq(\n).
										qq(<text>${chaptername}</text>).qq(\n).
										qq(</navLabel>).qq(\n).
										qq(<content src=\"mobi_temp_${chapter_index}.html\"/>).qq(\n).
										qq(</navPoint>);
			$html_totalfile_struct.=qq(<li><a href=\"mobi_temp_${chapter_index}.html\">${chaptername}</a></li>)."\n";
		}
		
		create_mobi_opf_file1($booktitle,$author,$current_date,"",$opf_file_name,$src_filename_new,$catagory_html_filename,$catagory_ncx_filename,$catagory_opf_file_part1,$catagory_opf_file_part2);
		create_mobi_ncx_file($booktitle,$author,$catagory_ncx_filename,$catagory_ncx_file_part1,$catagory_html_filename);
		create_mobi_html_struct_file($catagory_html_filename,$html_totalfile_struct,$default_cssfile);
	}
	else{
		#有目录,没有前言
	}
}

system("./kindlegen $opf_file_name");

clean_temp_files($opf_file_name,$src_filename,$src_filename_new,$mobi_file_name);


sub clean_temp_files{
    my ($opf_file_name,$src_filename,$src_filename_new,$mobi_file_name)=@_;
	if (-f $mobi_file_name){
		print "mobi generate succ\n";
	}
	else{
		print "mobi generate failed\n";
	}
	
	if (!-d $outputdir){
		`mkdir $outputdir`; 
	}
	
	foreach my $temp (@catagory_list){
		my ($nouse,$index)=split("#",$temp);
		#print $index,"\n";
        my $filename="mobi_temp_".$index.".html";
		`rm -f $filename`;
	}
	
	`mv $mobi_file_name $outputdir/$output_name`;
	`rm -f $opf_file_name`;
	`rm -f $src_filename`;
	`rm -f $src_filename_new`;
}


