# codes4kindle
A simple tool writes in perl,I can use it to covert a open-source project to a mobi file

codes4mobi.pl [options] 
Options:
    -h | --help         显示帮助信息                

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
        find Libevent/ | awk -F'/' '/^[^.]/{print $NF}' |awk -F '.' '{print $2}'|grep -v '^$'|sort |uniq -c |sort -k1nr
        1       perl codes4mobi.pl -i ./projectbasedir -s c -s h -o mobifile -a pandaychen -t gbase -ot project.mobi
        2       perl codes4mobi.pl -i ./projectbasedir -s c -s h -o mobifile -a pandaychen -t gbase -ot project.mobi -c 1 -p prefix.html
    3   perl codes4mobi.pl -i ./makefile_sample/ -s hpp -s cpp -s sh -s txt -s makefile -s txt -s md -s py -s pl -s pm -s conf -s xml -s json -s c -s h -s makefile -o mobifile -a pandaychen -t makefile -ot makefile.mobi -c 1 -p prefix.html

    3 perl codes4mobi.pl -i ./SimpleSpider  -s lua -s cc -s hh -s cpp -s hpp  -s tex -s sample -s java -s -s proto  -s hpp -s cpp -s sh -s txt -s makefile -s txt -s md -s py -s pl -s pm -s conf -s xml -s json -s c -s h -s makefile -o mobifile -a pandaychen -t SimpleSpider  -ot SimpleSpider.mobi -c 1 -p prefix.html 

Any Questions,Plz contact ringbuffer@126.com.