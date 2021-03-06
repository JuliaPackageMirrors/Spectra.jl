#############################################################################
#Copyright (c) 2016 Charles Le Losq
#
#The MIT License (MIT)
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the #Software without restriction, including without limitation the rights to use, copy, #modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, #and to permit persons to whom the Software is furnished to do so, subject to the #following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, #INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#############################################################################

function rameau(paths::Tuple,switches::Tuple;input_properties=('\t',0),prediction_coef=[0.0059;0.0005],temperature=23.0,laser=532.0,lb_break=1600.,hb_start=2600.,basetype="gcvspline")
	
	# some function definition
	calibration_model(x, p) = p[1].*x
	baseline_lfmodel(x, p) = p[1].*x + p[2].*x.^2 + p[3].*x.^3
	
	if switches[1] == "internal"
	
	
		scale = 1
	
		liste=readcsv(paths[1], skipstart=1)
		names = liste[:,1]
		water = Array{Float64}(liste[:,3])
		smo_lf = Array{Float64}(liste[:,4])
		smo_hf = Array{Float64}(liste[:,5])
		roi = ones(Int((size(liste,2)-5)/2),2,size(liste,1))
		for j = 1:size(liste,1)
			roi[:,1,j] = (liste[j,6:2:end])
			roi[:,2,j] = (liste[j,7:2:end])
		end

		rws = ones(size(liste,1),3)
	
		for i = 1:size(liste,1)   
			spectra = readdlm(string(paths[2],names[i]),input_properties[1],skipstart=input_properties[2])
    
			if spectra[end,1] < spectra[1,1]
				spectra = flipdim(spectra,1)
			end
    
			x = spectra[:,1]
			spectra[:,2] = spectra[:,2] - minimum(spectra[:,2])
			y = spectra[:,2]./maximum(spectra[:,2]).*scale + 0.1# area normalisation, and we avoid any 0
			ratio_bkg = minimum(y)/maximum(y) # to keep a record of the ratio of maximum signal intensity over minimum background intensity
			
			#### PRELIMINARY STEP: FIRST WE GRAB THE GOOD SIGNAL IN THE ROI
			interest_index::Array{Int64} = find(roi[1,1,i] .<= x[:,1] .<= roi[1,2,i])
			if size(roi)[1] > 1
				for j = 2:size(roi)[1]
					interest_index = vcat(interest_index,  find(roi[j,1,i] .<= x[:,1] .<= roi[j,2,i]))
				end
			end
			interest_x = x[interest_index,1]
			interest_y = y[interest_index,1]
    
			if switches[3] == "yes" # if user asks for the experimental baseline
        		
				if switches[4] == "yes"
					x, y_long, ~ = tlcorrection([x[:] y[:]],temperature,laser) # Long correction
					y_long=y_long./maximum(y_long).*scale
				
					### THE FOLLOWING IS PURELY EXPERIMENTAL
				
					lb = roi[:,1,i]
					hb = roi[:,2,i]

					roi_hf =  [lb[hb.>hb_start] hb[hb.>hb_start]]
					roi_lf =  [lb[hb.<lb_break] hb[hb.<lb_break]]
			
					y_hf = y_long[x.>hb_start]
					y_lf = y_long[x.<lb_break]
				
					# A first linear baseline in signals between ~1300 and ~ 2000 cm-1
					#y_calc_hf, baseline_hf = baseline(x,y_long,[2600. 3100.;3775. 3900.],"gcvspline",p=smo_hf[i])
					#y_calc_hf, baseline_hf = baseline(x,y_long,[roi_hf[end-1,1] roi_hf[end-1,2];roi_hf[end,1] roi_hf[end,2]],"poly",p=3.0)
					y_calc_hf, baseline_hf = baseline(x,y_long,[3000. 3100;3750. 3800.],"poly",p=1.0)
				
					x_fit = [x[0 .< x .< 150];x[1250. .< x .< 1500]]
					y_fit = [y_long[0 .< x .< 150];y_long[1250. .< x .< 1500.]]
				
					#sss = size(x_fit,1)
					#mod = Model(solver=IpoptSolver())
					#@variable(mod, k1 >= 0.0,start=1.0)
					#@variable(mod, k2 >= 0.0, start = 1.0)
					
					#@NLexpression(mod, base[k=1:sss],k1*x_fit[k] + k2*x_fit[k]*x_fit[k])
					#@NLobjective(mod,Min,sum{(base[k] - y_fit[k])^2,k=sss})
					#status = solve(mod)
					
					#p1 = getvalue(k1)
					#p2 = getvalue(k2)
					
					#fit_bas = curve_fit(baseline_lfmodel, , [y_long[0 .< x .< 100];y_long[1250. .< x .< 1500.]], [0.5,0.5,0.5])
					#coef_bas = fit_bas.param
					#baseline_lf = baseline_lfmodel(x,[p1;p2])
					#y_calc_lf = y_long - baseline_lf
					
					y_calc_lf, baseline_lf = baseline(x,y_long,[0. 150;1250. 1600.],"poly",p=3.0)
					#y_calc_lf, baseline_lf = baseline(x,y_long,roi[:,:,i],basetype,p=smo_lf[i])
					
					y_calc2 = [y_calc_lf[x.<=1600.];y_calc_hf[x.>1600.]]
					bas2 = [baseline_lf[x.<=1600.];baseline_hf[x.>1600.]]
					#y_calc2 = y_calc2[:,1]./trapz(x[:],y_calc2[:,1]).*scale # area normalisation
		
					figure(figsize=(20,20))
					suptitle("Baseline sub. with Long corr., sp. $(names[i])")
				
					subplot(3,2,(1,2))
					plot(x,y,"black",label="Raw sp.")
					plot(x,y_long,"blue",label="Long corr. sp.")
					scatter(interest_x,y_long[interest_index,1],s=10.,color="red",label="ROI") # the ROI signals after first baseline and long correction
					plot(x,bas2,"red",label="Baseline")
					legend(loc="best",fancybox="true")
			
					subplot(3,2,3)
					plot(x[x.<1500],y_long[x.<1500],"blue",label="Long corr. sp.")
					scatter(interest_x[interest_x.<1500],y_long[interest_index[interest_x.<1500],1],s=10.,color="red",label="ROI") # the ROI signals after first baseline and long correction
					plot(x[x.<1500],bas2[x.<1500],"red",label="Baseline")
					xlim(0,1500)
					legend(loc="best",fancybox="true")
			
					subplot(3,2,4)
					plot(x[x.>2800],y_long[x.>2800],"blue",label="Long corr. sp.")
					scatter(interest_x[interest_x.>2800],y_long[interest_index[interest_x.>2800],1],s=10.,color="red",label="ROI") # the ROI signals after first baseline and long correction
					plot(x[x.>2800],bas2[x.>2800],"red",label="Baseline")
					xlim(2800,4000)
					legend(loc="best",fancybox="true")
			
					subplot(3,2,(5,6))
					plot(x,y_calc2,"cyan",label="Final sp.")
					xlabel(L"Raman shift, cm$^{-1}$")
					ylabel("Intensity, area normalised")
					legend(loc="best",fancybox="true")
					
				else
					# ALSO FULLY EXPERIMENTAL!!!! IT DOES NOT WORK!
					y_hf = y[x.>hb_start]
					y_lf = y[x.<lb_break]
				
					# A first linear baseline in signals between ~1300 and ~ 2000 cm-1
					y_calc_hf, baseline_hf = baseline(x,y,[2600. 2900.;3775. 3900.],"poly",p=3.0)
					
				    #A first linear baseline in signals between ~1300 and ~ 2000 cm-1
				   	y_calc1_part1, baseline1 = baseline(x,y,[1300 1800.],"poly",p=1.0)
						
					# we get a mean signal for background below 1300 cm-1
					X_low_lf = x[y .== minimum(y[100 .<x.<1400])]
					b_low_lf = mean(y[X_low_lf[1]-10 .< x .< X_low_lf[1]+10])
					
					baseline1[x.<1250.] = b_low_lf
					y_calc1_part1 = y - baseline1
					
					bas2 = [baseline1[x.<lb_break];baseline_hf[x.>lb_break]]
					y_calc2 = [y_calc1_part1[x.<lb_break];y_calc_hf[x.>lb_break]]
					
					figure()
					plot(x,y,color="black")
					plot(x,baseline_hf,color="red")
					plot(x,y_calc2,color="blue")
				end
            
			else # only a single baseline treatment is asked
        
				# we test if thre Long correction is asked, and react accordingly for baseline substraction
				if switches[4] == "yes"
					x, y_long, ~ = tlcorrection([x[:] y[:]],temperature,laser) # Long correction
					y_long=y_long./maximum(y_long).*scale
				
					y_calc2, bas2 = baseline(x,y_long,roi[:,:,i],basetype,p=smo_lf[i])
					y_calc2 = y_calc2[:,1]./trapz(x[:],y_calc2[:,1]).*(scale./10) # area normalisation
            
					figure(figsize=(20,20))
					suptitle("LL2012 method, sp. $(names[i])")
					
					subplot(3,2,(1,2))
					plot(x,y,"black",label="Raw sp.")
					plot(x,y_long,"blue",label="Long corr. sp.")
					scatter(interest_x,y_long[interest_index,1],s=10.,color="red",label="ROI") # the ROI signals after first baseline and long correction
					plot(x,bas2,"red",label="Baseline")
					legend(loc="best",fancybox="true")
					
					xlabel(L"Raman shift, cm$^{-1}$",fontsize=18,fontname="Arial")
					ylabel("Intensity,a. u.",fontsize=18,fontname="Arial")
				
					subplot(3,2,3)
					plot(x[x.<1500],y_long[x.<1500],"blue",label="Long corr. sp.")
					scatter(interest_x[interest_x.<1500],y_long[interest_index[interest_x.<1500],1],s=10.,color="red",label="ROI") # the ROI signals after first baseline and long correction
					plot(x[x.<1500],bas2[x.<1500],"red",label="Baseline")
					xlim(0,1500)
					legend(loc="best",fancybox="true")
					xlabel(L"Raman shift, cm$^{-1}$",fontsize=18,fontname="Arial")
					ylabel("Intensity,a. u.",fontsize=18,fontname="Arial")
				
					subplot(3,2,4)
					plot(x[x.>2800],y_long[x.>2800],"blue",label="Long corr. sp.")
					scatter(interest_x[interest_x.>2800],y_long[interest_index[interest_x.>2800],1],s=10.,color="red",label="ROI") # the ROI signals after first baseline and long correction
					plot(x[x.>2800],bas2[x.>2800],"red",label="Baseline")
					xlim(2600,4000)
					legend(loc="best",fancybox="true")
					xlabel(L"Raman shift, cm$^{-1}$",fontsize=18,fontname="Arial")
					ylabel("Intensity,a. u.",fontsize=18,fontname="Arial")
				
					subplot(3,2,(5,6))
					plot(x,y_calc2,"cyan",label="Final sp.")
					xlabel(L"Raman shift, cm$^{-1}$")
					ylabel("Intensity, area normalised")
					legend(loc="best",fancybox="true")
					xlabel(L"Raman shift, cm$^{-1}$",fontsize=18,fontname="Arial")
					ylabel("Intensity,a. u.",fontsize=18,fontname="Arial")
            
				else
					y_calc2, bas2 = baseline(x,y,roi[:,:,i],basetype,p=smo_lf[i])
					y_calc2 = y_calc2[:,1]./trapz(x[:],y_calc2[:,1]).*scale # area normalisation
            
					figure()
					plot(x,y.*10,"black",label="Raw sp.")
					scatter(interest_x,interest_y.*10,s=10.,color="red",label="ROI")
					plot(x,bas2.*10,"red",label="Baseline")
					plot(x,y_calc2,"cyan",label="Final sp.")
					xlabel(L"Raman shift, cm$^{-1}$")
					ylabel("Intensity, area normalised")
					title("Baseline sub., NO Long corr.")
					legend(loc="best",fancybox="true")
				end
        
			end
    
			# saving the corrected spectrum
			writecsv(string(paths[3],names[i]),[x y_calc2 bas2])
    
			#Saving the generated figure (specified directory should exist)
			savefig(string(paths[4],"baseline_",names[i],".pdf"))
    		close()
			if switches[3] == "yes"
				# calc=ulating the areas under silicate and water bands
				
				if switches[4] == "yes"
					As = (trapz(x[150 .<x.<600],y_calc2[150 .<x.<600])+trapz(x[1000 .<x.<1250],y_calc2[1000 .<x.<1250]))
					
					Aw = trapz(x[3100 .< x .<3750],y_calc2[3100 .< x .<3750])
				else
					
					#idx1a = find(y[400 .<x.<600] .== maximum(y[400 .<x.<600]))
					#idx1b = find(y[600 .<x.<1000] .== minimum(y[600 .<x.<1000]))
					
					#idx2a = find( y[900 .<x.<1250] .== maximum(y[900 .<x.<1250]))
					#idx2b = find( y[1000 .<x.<1250] .== minimum(y[1000 .<x.<1250]))
					
					#idx3a = find( y[3000 .<x.<3700] .== maximum(y[3000 .<x.<3700]))
					#idx3b = find( y[3700 .<x.<3800] .== minimum(y[3700 .<x.<3800]))
					
					#As = mean(y[(idx1a[1]-4):(idx1a[1]+4),1]) - mean(y[(idx1b[1]-4):(idx1b[1]+4),1]) + mean(y[(idx2a[1]-4):(idx2a[1]+4),1]) - mean(y[(idx2b[1]-4):(idx2b[1]+4),1])
					#Aw = mean(y[idx3a[1]-4 : idx3a[1]+4,1]) - mean(y[idx3b[1]-4 : idx3b[1]+4,1])
					
					As = maximum(y[400 .<x.<600]) - minimum(y[600 .<x.<1000]) + maximum(y[900 .<x.<1250]) - minimum(y[1000 .<x.<1250])
					Aw = maximum(y[3000 .<x.<3700]) - minimum(y[3700 .<x.<3800])
				end
			else
				# calc=ulating the areas under silicate and water bands
				As = trapz(x[150 .< x .<1300],y_calc2[150 .< x .<1300])
				Aw = trapz(x[2800 .< x .<3750],y_calc2[2800 .< x .<3750])
			end
    
			# recording them
			rws[i,1] = As;
			rws[i,2] = Aw;
			rws[i,3] = Aw./(As);
			println("Spectrum $(names[i]), the rws is $(rws[i,3])")
		end
	
		if switches[2] == "yes"
			fit = curve_fit(calibration_model, rws[:,3], water[:]./(100.-water[:]), [0.5])
			coef = fit.param
			sigma = estimate_errors(fit, 0.95)

			rws_calibration = collect(0:0.01:round(maximum(rws[:,3]),2))
			water_ratio_calibration = calibration_model(rws_calibration,coef)
			water_compare =  100.*calibration_model(rws[:,3],coef)./(calibration_model(rws[:,3],coef)+1) # eq. 3 Le Losq et al. (2012)

			rmse_calibration = sqrt(1./(size(rws,1)-1).*sum((water_compare-water).^2))
			rmse_ratio_ws = rmse_calibration/100*(rmse_calibration/(100-rmse_calibration)+1)
        
			figure()
			scatter(rws[:,3],water[:]./(100.-water[:]))
			plot(rws_calibration,water_ratio_calibration,color="red",linewidth=2.0)
			plot(rws_calibration,water_ratio_calibration+rmse_ratio_ws,color="red",linestyle="--",linewidth=1.0)
			plot(rws_calibration,water_ratio_calibration-rmse_ratio_ws,color="red",linestyle="--",linewidth=1.0)
			plot(rws_calibration,water_ratio_calibration,color="red")
			xlim(0,maximum(rws_calibration)+1./4*maximum(rws_calibration))
			ylim(0,maximum(water_ratio_calibration)+1./4*maximum(water_ratio_calibration))
			
			xlabel(L"A$_{water}$/A$_{silicates}$, area ratio",fontsize=18,fontname="Arial")
			ylabel("Water/Glass, weight ratio",fontsize=18,fontname="Arial")
			annotate(L"R$_{ws}$=",xy=(0.3,0.9),xycoords="axes fraction",fontsize=18,fontname="Arial",horizontalalignment="center")
			annotate("$(round(coef[1],5)) +/- $(round(sigma[1],5))",xy=(0.3,0.8),xycoords="axes fraction",fontsize=18,fontname="Arial",horizontalalignment="center")
			annotate("Standard deviation\n= $(round(rmse_calibration,2)) wt%",xy=(0.7,0.3),xycoords="axes fraction",horizontalalignment="center",fontsize=18,fontname="Arial")
			savefig(paths[6])
        
			writecsv(string(paths[5]), ["spectrum" "product" "Rws" "Water input" "Water Raman";liste[:,1] liste[:,2] rws[:,3] water water_compare])
			#return [rws[:,3] water water_compare]   
		else
			water_predicted = 100.*(rws[:,3].*prediction_coef[1]./(rws[:,3].*prediction_coef[1]+1))
			water_predicted_high = 100.*(rws[:,3].*sum(prediction_coef)./(rws[:,3].*sum(prediction_coef)+1)) 
			writecsv(string(paths[5]), ["spectrum" "product" "Rws" "Water Raman" "Error";liste[:,1] liste[:,2] rws[:,3] water_predicted water_predicted_high-water_predicted])
			#return [rws[:,3] water_predicted]
		end        
		
	elseif switches[1] == "external"
		liste=readcsv(paths[1], skipstart=1)
		
		reference = liste[:,1]
		# reference product names are in first column for record
		reference_density = liste[:,3]
		reference_water = liste[:,4]
		
		sample = liste[:,5]
		# sample product names are in column 6 for record
		sample_density = liste[:,7]
		
		water = ones(size(liste,1),1) # the array to record water content
		
		for i = 1:size(liste,1)
			
			#importing data
			reference_sp = readdlm(string(paths[2],reference[i]),input_properties[1],skipstart=input_properties[2])
			sample_sp = readdlm(string(paths[2],sample[i]),input_properties[1],skipstart=input_properties[2])
			
			if reference_sp[end,1] < reference_sp[1,1]
				reference_sp = flipdim(reference_sp,1)
			end
			
			if sample_sp[end,1] < sample_sp[1,1]
				sample_sp = flipdim(sample_sp,1)
			end
			
			# temperature - excitation line correction with the Hehlen formula
			x_ref, reference_sp_long, ~ = tlcorrection(reference_sp,temperature,laser,correction="hehlen",normalisation="no",density=reference_density[i])
			x_sp, sample_sp_long, ~ = tlcorrection(sample_sp,temperature,laser,correction="hehlen",normalisation="no",density=sample_density[i])
			
			# Linear baseline subtraction
			roi_hf = [3000. 3100.; 3800. 3900.] # the region where the basline is constrained
			reference_sp_corr2, reference_baseline = baseline(x_ref,reference_sp_long,roi_hf,"poly",p=1.0)
			sample_sp_corr2, sample_baseline = baseline(x_sp,sample_sp_long,roi_hf,"poly",p=1.0)
			
			# Area calculation between 3100 and 3800 cm-1
			Area_reference = trapz(x_ref[3100. .<x_ref[:,1].<3800.],reference_sp_corr2[3100. .<x_ref[:,1].<3800.])
			Area_sample = trapz(x_sp[3100. .<x_sp[:,1].<3800.],sample_sp_corr2[3100. .<x_sp[:,1].<3800.])
			
			# With the intensity
			Intensity_reference = maximum(reference_sp_corr2[3100. .<x_ref[:,1].<3800])
			Intensity_sample = maximum(sample_sp_corr2[3100. .<x_ref[:,1].<3800])

			# Water calculation
			water[i] = (reference_water[i]./1.8*reference_density[i]) .*Area_sample./Area_reference # water is in mol/L
			#water[i] = (reference_water[i]./1.8*reference_density[i]) .*Intensity_sample./Intensity_reference # water is in mol/L
			
			water[i] = water[i] *1.8./sample_density[i] # water converted in wt%
			
			figure(figsize=(7.5,15))
			
			subplot(311)
			title("External calibration: $(round(water[i],2)) wt% water,\n sp. $(sample[i]) with ref. $(reference[i]) ")
			plot(reference_sp[:,1],reference_sp[:,2],color="black",label="Reference")
			plot(sample_sp[:,1],sample_sp[:,2],color="blue",label="Sample")
			xlabel(L"Raman shift, cm$^{-1}$",fontsize=18,fontname="Arial")
			legend(loc="best",frameon=false)
			
			subplot(312)
			plot(x_ref[:],reference_sp_long[:],color="black",label=L"T-$\nu$ corrected reference")
			plot(x_ref[:],reference_baseline,color="grey",label="Reference baseline")
			plot(x_sp[:],sample_sp_long[:],color="blue",label=L"T-$\nu$ corrected sample")
			plot(x_sp[:],sample_baseline,color="cyan",label="Sample baseline")
			xlabel(L"Raman shift, cm$^{-1}$",fontsize=18,fontname="Arial")
			ylabel("Normalized intensity, a. u.",fontsize=18,fontname="Arial")
			legend(loc="best",frameon=false)
			
			subplot(313)
			plot(x_ref,reference_sp_corr2,color="black",label="Ref. spectrum")
			plot(x_sp,sample_sp_corr2,color="blue",label="Sample spectrum")
			xlabel(L"Raman shift, cm$^{-1}$",fontsize=18,fontname="Arial")
			legend(loc="best",frameon=false)
			tight_layout()
			# saving the water content
			writecsv(string(paths[5]), ["Spectrum" "Sample Name" "Estimated water content";liste[:,5] liste[:,6] water])
			
			#Saving the generated figure (specified directory should exist)
			savefig(string(paths[4],"Internal_Std_",sample[i],".pdf"))
			
		end
		   
		   
	else # or error message
		error("the first switch indicates if you want to use an internal or external calibration mode. Please choose between both.")
	end
end

