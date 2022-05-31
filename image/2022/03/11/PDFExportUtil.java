package com.meadel.export.demo4;

import com.itextpdf.text.Font;
import com.itextpdf.text.Image;
import com.itextpdf.text.*;
import com.itextpdf.text.pdf.BaseFont;
import com.itextpdf.text.pdf.PdfWriter;
import com.meadel.export.demo01.PdfUtil;
import org.jfree.chart.ChartFactory;
import org.jfree.chart.ChartUtils;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.axis.CategoryAxis;
import org.jfree.chart.axis.ValueAxis;
import org.jfree.chart.labels.ItemLabelAnchor;
import org.jfree.chart.labels.ItemLabelPosition;
import org.jfree.chart.labels.StandardCategoryItemLabelGenerator;
import org.jfree.chart.labels.StandardPieSectionLabelGenerator;
import org.jfree.chart.plot.CategoryPlot;
import org.jfree.chart.plot.PiePlot3D;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.renderer.category.BarRenderer;
import org.jfree.chart.renderer.category.LineAndShapeRenderer;
import org.jfree.chart.title.TextTitle;
import org.jfree.chart.ui.TextAnchor;
import org.jfree.data.category.CategoryDataset;
import org.jfree.data.general.PieDataset;

import javax.servlet.http.HttpServletResponse;
import java.awt.*;
import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.net.URLEncoder;
import java.text.DecimalFormat;
import java.text.NumberFormat;

/**
 * @author X-MD
 * @version 1.0.0
 * @Description TODO
 * @createTime 2022年01月19日 16:47:00
 */
public class PDFExportUtil {

     public static void pdfExport(HttpServletResponse response,String filename, PieDataset dataset, CategoryDataset lineDataset,CategoryDataset dataSet) throws Exception{
          response.setContentType("application/pdf");
          response.addHeader("Content-Disposition", "inline;filename=" + URLEncoder.encode(filename, "UTF-8") + ".pdf");
          OutputStream os = new BufferedOutputStream(response.getOutputStream());
          // 1. Document document = new Document();
          Document document = PdfUtil.createDocument();
          // 2. 获取writer
          PdfWriter.getInstance(document, os);
          // 3. open()
          document.open();

          //设置中文样式（不设置，中文将不会显示）
          BaseFont bfChinese = BaseFont.createFont("STSong-Light", "UniGB-UCS2-H", BaseFont.NOT_EMBEDDED);
          Font fontChinese_content = new Font(bfChinese, 10, Font.NORMAL, BaseColor.BLACK);

          /**
           * 生成统计图
           */
//          PieDataset dataset = pieDataSet();
          JFreeChart chart = ChartFactory.createPieChart3D(" 项目进度分布", dataset, true, true, false);
          PiePlot3D plot = (PiePlot3D) chart.getPlot();
          //设置Label字体
          plot.setLabelFont(new java.awt.Font("微软雅黑", java.awt.Font.BOLD, 12));
          //设置legend字体
          chart.getLegend().setItemFont(new java.awt.Font("微软雅黑", java.awt.Font.BOLD, 12));
          // 图片中显示百分比:默认方式
          //plot.setLabelGenerator(new StandardPieSectionLabelGenerator(StandardPieToolTipGenerator.DEFAULT_TOOLTIP_FORMAT));
          // 图片中显示百分比:自定义方式，{0} 表示选项， {1} 表示数值， {2} 表示所占比例 ,小数点后两位
          plot.setLabelGenerator(new StandardPieSectionLabelGenerator("{0}={1}({2})", NumberFormat.getNumberInstance(), new DecimalFormat("0.00%")));
          // 图例显示百分比:自定义方式， {0} 表示选项， {1} 表示数值， {2} 表示所占比例
          plot.setLegendLabelGenerator(new StandardPieSectionLabelGenerator("{0}={1}({2})"));
          // 设置背景色为白色
          chart.setBackgroundPaint(Color.white);
          // 指定图片的透明度(0.0-1.0)
          plot.setForegroundAlpha(1.0f);
          // 指定显示的饼图上圆形(false)还椭圆形(true)
          plot.setCircular(true);
          // 设置图标题的字体
          java.awt.Font font = new java.awt.Font(" 黑体", java.awt.Font.CENTER_BASELINE, 20);
          TextTitle title = new TextTitle("项目状态分布");
          title.setFont(font);
          chart.setTitle(title);
          String templatePath = PDFExportUtil.class.getResource("/").getPath() + "/templates/statistics.jpg";
          try {
               FileOutputStream fos_jpg = new FileOutputStream(templatePath);
               ChartUtils.writeChartAsJPEG(fos_jpg, 0.7f, chart, 800, 1000, null);
               fos_jpg.close();
          } catch (Exception e) {
               e.printStackTrace();
          }

          Paragraph pieParagraph = new Paragraph("02、饼状图测试", fontChinese_content);
          pieParagraph.setAlignment(Paragraph.ALIGN_LEFT);
          document.add(pieParagraph);
          Image pieImage = Image.getInstance(templatePath);
          pieImage.setAlignment(Image.ALIGN_CENTER);
          pieImage.scaleAbsolute(328, 370);
          document.add(pieImage);

          /**
           * 折线图
           */
//          CategoryDataset lineDataset = lineDataset();
          JFreeChart lineChart = ChartFactory.createLineChart("java图书销量", "java图书", "销量", lineDataset, PlotOrientation.VERTICAL, true, true, true);
          lineChart.getLegend().setItemFont(new java.awt.Font("宋体", java.awt.Font.PLAIN, 12));
          //获取title
          lineChart.getTitle().setFont(new java.awt.Font("宋体", java.awt.Font.BOLD, 16));

          //获取绘图区对象
          CategoryPlot linePlot = lineChart.getCategoryPlot();
          //设置绘图区域背景的 alpha 透明度 ,在 0.0f 到 1.0f 的范围内
          linePlot.setBackgroundAlpha(0.0f);

          //区域背景色
          //linePlot.setBackgroundPaint(Color.white);

          //背景底部横虚线
          linePlot.setRangeGridlinePaint(Color.gray);
          //linePlot.setOutlinePaint(Color.RED);//边界线

          // 设置水平方向背景线颜色
          // 设置是否显示水平方向背景线,默认值为true
          linePlot.setRangeGridlinesVisible(true);
          // 设置垂直方向背景线颜色
          linePlot.setDomainGridlinePaint(Color.gray);
          // 设置是否显示垂直方向背景线,默认值为false
          linePlot.setDomainGridlinesVisible(true);


          //获取坐标轴对象
          CategoryAxis lineAxis = linePlot.getDomainAxis();
          //设置坐标轴字体
          lineAxis.setLabelFont(new java.awt.Font("宋体", java.awt.Font.PLAIN, 12));
          //设置坐标轴标尺值字体（x轴）
          lineAxis.setTickLabelFont(new java.awt.Font("宋体", java.awt.Font.PLAIN, 12));
          //获取数据轴对象（y轴）
          ValueAxis rangeAxis = linePlot.getRangeAxis();
          rangeAxis.setLabelFont(new java.awt.Font("宋体", java.awt.Font.PLAIN, 12));

          //将折线设置为虚线
          LineAndShapeRenderer renderer = (LineAndShapeRenderer) linePlot.getRenderer();

          //利用虚线绘制
//        float[] dashes = {5.0f};
//        BasicStroke brokenLine = new BasicStroke(2.2f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND, 8f, dashes, 0.6f);
//        renderer.setSeriesStroke(0, brokenLine);
          // 设置显示小图标
          renderer.setDefaultShapesVisible(true);

          //折点显式数值
//        DecimalFormat decimalformat1 = new DecimalFormat("##"); // 数据点显示数据值的格式
//        renderer.setDefaultItemLabelGenerator(new StandardCategoryItemLabelGenerator("{2}", decimalformat1));
//        renderer.setDefaultItemLabelsVisible(true); // 设置项标签显示
//        renderer.setDefaultItemLabelsVisible(true); // 基本项标签显示

          /*
           * 生成图片
           */
          try {
               FileOutputStream fos = new FileOutputStream(templatePath);
               ChartUtils.writeChartAsJPEG(fos, 0.7f, lineChart, 600, 300);
          } catch (Exception e) {
               e.printStackTrace();
          }

          Paragraph lineParagraph = new Paragraph("02、折线图测试", fontChinese_content);
          lineParagraph.setAlignment(Paragraph.ALIGN_LEFT);
          document.add(lineParagraph);
          Image image = Image.getInstance(templatePath);
          image.setAlignment(Image.ALIGN_CENTER);
          image.scaleAbsolute(400, 200);
          document.add(image);

          //分页
          document.newPage();

          //柱状图测试
//          CategoryDataset dataSet = getDataSet2();
          JFreeChart jfreechart = ChartFactory.createBarChart("水果销售统计图", "水果", "销量", dataSet);

          CategoryPlot categoryPlot = jfreechart.getCategoryPlot();
          categoryPlot.setBackgroundAlpha(0.0f);
          categoryPlot.setRangeGridlinePaint(Color.gray);
          categoryPlot.setRangeGridlinesVisible(true);
          // 设置网格beijingse
          categoryPlot.setBackgroundPaint(Color.WHITE);
          // 设置网格竖线颜色
          categoryPlot.setDomainGridlinePaint(Color.pink);
          // 设置网格横线颜色
          categoryPlot.setRangeGridlinePaint(Color.pink);

          // 显示每个柱的数值，并修改该数值的字体属性
          BarRenderer renderer2= new BarRenderer();
          renderer2.setDefaultItemLabelGenerator(new StandardCategoryItemLabelGenerator());
          renderer2.setDefaultItemLabelsVisible(true);
          renderer2.setDefaultPositiveItemLabelPosition(new ItemLabelPosition(ItemLabelAnchor.INSIDE8, TextAnchor.BASELINE_CENTER));
          renderer2.setItemLabelAnchorOffset(10D);

          // 设置平行柱的之间距离
          renderer2.setItemMargin(0.2);
          categoryPlot.setRenderer(renderer2);

          FileOutputStream fos = new FileOutputStream(templatePath);
          ChartUtils.writeChartAsJPEG(fos, 0.7f, jfreechart, 600, 300);

          Paragraph paragraph = new Paragraph("03、柱状图测试", fontChinese_content);
          paragraph.setAlignment(Paragraph.ALIGN_LEFT);
          document.add(paragraph);
          Image image2 = Image.getInstance(templatePath);
          image2.setAlignment(Image.ALIGN_CENTER);
          image2.scaleAbsolute(400, 200);
          document.add(image2);




          // 5. close()
          document.close();
          os.close();
     }
}
