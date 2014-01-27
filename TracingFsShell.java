import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FsShell;
import org.apache.hadoop.tracing.SpanReceiverHost;
import org.apache.hadoop.util.ToolRunner;
import org.cloudera.htrace.Sampler;
import org.cloudera.htrace.Trace;
import org.cloudera.htrace.TraceScope;

public class TracingFsShell {
  public static void main(String argv[]) throws Exception {
    Configuration conf = new Configuration();
    FsShell shell = new FsShell();
    conf.setQuietMode(false);
    shell.setConf(conf);
    int res = 0;
    SpanReceiverHost.init(conf);
    TraceScope ts = null;
    try {
      ts = Trace.startSpan("FsShell", Sampler.ALWAYS);
      res = ToolRunner.run(shell, argv);
    } finally {
      shell.close();
      if (ts != null) ts.close();
    }
    System.exit(res);
  }
}
