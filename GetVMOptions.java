import java.util.ArrayList;
import java.util.List;
import java.lang.Class;
import java.lang.management.ManagementFactory;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import javax.management.MBeanServer;
import com.sun.management.HotSpotDiagnosticMXBean;
import com.sun.management.VMOption;
import com.sun.management.VMOption.Origin;

public class GetVMOptions {
  public static void main(String[] args) {
    MBeanServer pfServer = ManagementFactory.getPlatformMBeanServer();
    HotSpotDiagnosticMXBean proxy = null;
    try {
      proxy = ManagementFactory.newPlatformMXBeanProxy(pfServer,
                                                       "com.sun.management:type=HotSpotDiagnostic",
                                                       HotSpotDiagnosticMXBean.class);
    } catch (Exception e) {
      e.printStackTrace();
    }
    //List<VMOption> options = proxy.getDiagnosticOptions();

    ClassLoader cl = GetVMOptions.class.getClassLoader();
    Class clazz = null;
    try {
      clazz = cl.loadClass("sun.management.Flag");
    } catch (ClassNotFoundException e) {
      e.printStackTrace();
    }
    Constructor cons = null;
    try {
      Class[] types = new Class[] {String.class, Object.class, boolean.class, boolean.class, Origin.class};
      cons = clazz.getDeclaredConstructor(types);
    } catch (java.lang.NoSuchMethodException e) {
      e.printStackTrace();
    }
    cons.setAccessible(true);
    Method getAllFlags = null;
    Method getVMOption = null;
    try {
      getAllFlags = clazz.getDeclaredMethod("getAllFlags", new Class[]{});
      getVMOption = clazz.getDeclaredMethod("getVMOption", new Class[]{});
    } catch (java.lang.NoSuchMethodException e) {
      e.printStackTrace();
    }
    getAllFlags.setAccessible(true);
    getVMOption.setAccessible(true);
    Object ret = null;
    try {
      ret = getAllFlags.invoke(new Object[]{});
    } catch (IllegalAccessException e) {
      e.printStackTrace();
    } catch (java.lang.reflect.InvocationTargetException e) {
      e.printStackTrace();
    }
    for (Object flag : (List<Object>)ret) {
      try {
        System.out.println((VMOption)(getVMOption.invoke(flag, new Object[]{})));
      } catch (NullPointerException e) {
        //e.printStackTrace();
      } catch (IllegalAccessException e) {
        //e.printStackTrace();
      } catch (java.lang.reflect.InvocationTargetException e) {
        //e.printStackTrace();
      }
    }
  }
}
